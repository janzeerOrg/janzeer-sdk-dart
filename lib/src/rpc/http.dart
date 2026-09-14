/// JSON-RPC 2.0 over HTTP (`POST /rpc`).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors.dart';
import '../json.dart';
import 'methods.dart';

/// One batch request.
class BatchRequest {
  /// method
  final String method;

  /// params by name or position
  final Object? params;

  /// Construct.
  const BatchRequest(this.method, [this.params]);
}

/// One batch outcome: [result] on success, [error] on failure (never throws for a single failed entry).
class BatchResult {
  /// the lossless result tree
  final Object? result;

  /// the mapped error
  final JanzeerException? error;

  /// Construct.
  const BatchResult({this.result, this.error});

  /// success?
  bool get ok => error == null;
}

/// JSON-RPC over HTTP.
class JanzeerRpc extends RpcMethods {
  /// `http://host:7019/rpc`
  final String url;

  final http.Client _http;
  final Duration _timeout;
  final Map<String, String> _headers;
  final bool _retry429;
  int _id = 0;

  /// [url] may be a bare origin or an `/api/v1` base — it is rewritten to `/rpc`. [timeout] defaults to 65 s
  /// (above the node's 60 s `waitForFinality` cap).
  JanzeerRpc(String url,
      {http.Client? httpClient,
      Duration timeout = const Duration(seconds: 65),
      Map<String, String> headers = const {},
      bool retryOnRateLimit = true})
      : url = normalizeRpcUrl(url),
        _http = httpClient ?? http.Client(),
        _timeout = timeout,
        _headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...headers
        },
        _retry429 = retryOnRateLimit;

  /// Release the underlying HTTP client.
  void close() => _http.close();

  @override
  Future<Object?> call(String method, [Object? params]) async {
    final id = ++_id;
    final body = await _post({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params
    });
    if (body is! Map<String, Object?>) {
      throw const NetworkException('malformed JSON-RPC response');
    }
    final err = body['error'];
    if (err != null) throw rpcErrorFrom(asObject(toPlain(err)));
    return body['result'];
  }

  /// Send several requests in one HTTP round trip (node cap: 50). Results come back in request order.
  Future<List<BatchResult>> batch(List<BatchRequest> requests) async {
    if (requests.isEmpty) return const [];
    final ids = requests.map((_) => ++_id).toList();
    final body = await _post([
      for (var i = 0; i < requests.length; i++)
        {
          'jsonrpc': '2.0',
          'id': ids[i],
          'method': requests[i].method,
          if (requests[i].params != null) 'params': requests[i].params
        }
    ]);
    if (body is Map<String, Object?>) {
      final err = body['error'];
      throw err != null
          ? rpcErrorFrom(asObject(toPlain(err)))
          : const NetworkException('malformed JSON-RPC batch response');
    }
    final byId = <int, Map<String, Object?>>{};
    for (final item in asArray(body)) {
      if (item is Map<String, Object?> && item['id'] != null) {
        byId[asInt(item['id'])] = item;
      }
    }
    return ids.map((id) {
      final r = byId[id];
      if (r == null) {
        return const BatchResult(
            error: RpcException(RpcCodes.internal, 'missing batch response'));
      }
      final err = r['error'];
      if (err != null) {
        return BatchResult(error: rpcErrorFrom(asObject(toPlain(err))));
      }
      return BatchResult(result: r['result']);
    }).toList();
  }

  Future<Object?> _post(Object payload, [int attempt = 0]) async {
    http.Response res;
    try {
      res = await _http
          .post(Uri.parse(url), headers: _headers, body: jsonEncode(payload))
          .timeout(_timeout);
    } on TimeoutException catch (e) {
      throw NetworkException(
          'Node not responding at $url (timeout after ${_timeout.inSeconds}s)',
          e);
    } on http.ClientException catch (e) {
      throw NetworkException('Cannot reach the node at $url: ${e.message}', e);
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    final Object? json;
    try {
      json = parseJson(res.body);
    } on FormatException catch (e) {
      throw NetworkException('Node returned non-JSON (${res.statusCode})', e);
    }
    if (res.statusCode == 429) {
      final secs = int.tryParse(res.headers['retry-after'] ?? '') ?? 1;
      final err = RateLimitedException(
          'Rate limit exceeded', Duration(seconds: secs), Transport.rpc);
      if (_retry429 && attempt == 0) {
        await Future<void>.delayed(err.retryAfter);
        return _post(payload, 1);
      }
      throw err;
    }
    return json;
  }
}

/// Rewrite an origin / `/api/v1` base / `/rpc` url to the `/rpc` endpoint.
String normalizeRpcUrl(String url) {
  var u = url.trim().replaceFirst(RegExp(r'/+$'), '');
  u = u.replaceFirst(RegExp(r'/api/v1$'), '');
  if (!u.endsWith('/rpc')) u += '/rpc';
  return u;
}
