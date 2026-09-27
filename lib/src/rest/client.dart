/// Typed client of the node's REST API (`/api/v1/`).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors.dart';
import '../json.dart';
import '../tx/types.dart';
import 'models.dart';

/// The REST envelope metadata of the last successful call.
class Envelope {
  /// server time (ms)
  final int timestamp;

  /// API version (`1.1.0`)
  final String version;

  /// Construct.
  const Envelope(this.timestamp, this.version);
}

/// Sentinel for "no notFound default".
const Object _noDefault = Object();

/// Typed REST client.
class JanzeerClient {
  /// e.g. `http://localhost:7019/api/v1/` (a missing `/api/v1/` suffix is added)
  final String baseUrl;

  /// envelope of the last successful response
  Envelope? lastEnvelope;

  final http.Client _http;
  final Duration _timeout;
  final Map<String, String> _headers;
  final bool _retry429;

  /// Create a client. [httpClient] lets you inject a custom/mock client; [timeout] defaults to 15 s;
  /// [retryOnRateLimit] retries once after a 429 (safe: transaction acceptance is idempotent by hash).
  JanzeerClient(String baseUrl,
      {http.Client? httpClient,
      Duration timeout = const Duration(seconds: 15),
      Map<String, String> headers = const {},
      bool retryOnRateLimit = true})
      : baseUrl = _normalize(baseUrl),
        _http = httpClient ?? http.Client(),
        _timeout = timeout,
        _headers = {'Accept': 'application/json', ...headers},
        _retry429 = retryOnRateLimit {
    transfers = TxApi<TransferTx>._(
        this, 'transactions/transfers', TransferTx.fromJson);
    validatorTxs = TxApi<RegisterValidatorTx>._(
        this, 'transactions/validators', RegisterValidatorTx.fromJson);
    exitValidatorTxs = TxApi<ExitValidatorTx>._(
        this, 'transactions/exit-validators', ExitValidatorTx.fromJson);
    tokenTxs = TxApi<TokenTx>._(this, 'transactions/tokens', TokenTx.fromJson);
    rewards =
        TxApi<RewardTx>._(this, 'transactions/rewards', RewardTx.fromJson);
    blocks = BlocksApi._(this);
    validators = ValidatorsApi._(this);
    tokens = TokensApi._(this);
  }

  static String _normalize(String u) {
    var s = u.trim().replaceFirst(RegExp(r'/+$'), '');
    if (!s.endsWith('/api/v1')) s += '/api/v1';
    return '$s/';
  }

  /// Release the underlying HTTP client.
  void close() => _http.close();

  // ---- low level ------------------------------------------------------------------------------------------

  /// `GET path?query` → the envelope `payload` (lossless JSON tree). [notFound] short-circuits a 404.
  Future<Object?> get(String path,
          {Map<String, Object?>? query, Object? notFound = _noDefault}) =>
      _request('GET', path + _qs(query), null, notFound);

  /// `POST path` with a JSON body → the envelope `payload`.
  Future<Object?> post(String path, Object body) =>
      _request('POST', path, body, _noDefault);

  Future<Object?> _request(
          String method, String path, Object? body, Object? notFound,
          [int attempt = 0]) =>
      _requestAt(baseUrl, method, path, body, notFound, attempt);

  Future<Object?> _requestAt(
      String base, String method, String path, Object? body, Object? notFound,
      [int attempt = 0]) async {
    final uri = Uri.parse(base + path.replaceFirst(RegExp('^/'), ''));
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      res = await http.Response.fromStream(await _http.send(req))
          .timeout(_timeout);
    } on TimeoutException catch (e) {
      throw NetworkException(
          'Node not responding at $baseUrl (timeout after ${_timeout.inSeconds}s)',
          e);
    } on http.ClientException catch (e) {
      throw NetworkException(
          'Cannot reach the node at $baseUrl: ${e.message}', e);
    }
    // Follow ONE redirect for every method. package:http only follows redirects for GET/HEAD, so a base URL
    // like `http://node.example/api/v1/` behind an http→https redirect read fine but every POST (transfers!)
    // failed with a bare 301 (Flutter wallet, online test 2026-09-23). The node's API never redirects itself, so a
    // redirect always means "same API, other scheme/host": re-issue the same request there, once.
    final location = res.headers['location'];
    if (attempt == 0 &&
        location != null &&
        const {301, 302, 307, 308}.contains(res.statusCode)) {
      final target = uri.resolve(location);
      final tail = RegExp.escape(path.replaceFirst(RegExp('^/'), ''));
      final base = target.toString().replaceFirst(RegExp('/*$tail\$'), '/');
      return _requestAt(base, method, path, body, notFound, 1);
    }
    if (res.statusCode == 404 && !identical(notFound, _noDefault)) {
      return notFound;
    }
    Object? json;
    if (res.body.isNotEmpty) {
      try {
        json = parseJson(res.body);
      } on FormatException catch (e) {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          throw NetworkException(
              'Node returned non-JSON (${res.statusCode})', e);
        }
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = restErrorFrom(
          res.statusCode, json == null ? null : toPlain(json),
          retryAfterHeader: res.headers['retry-after']);
      if (err is RateLimitedException && _retry429 && attempt == 0) {
        await Future<void>.delayed(err.retryAfter);
        return _request(method, path, body, notFound, 1);
      }
      throw err;
    }
    if (json is Map<String, Object?> && json.containsKey('payload')) {
      lastEnvelope = Envelope(
          asOptInt(json['timestamp']) ?? 0, asOptString(json['version']) ?? '');
      return json['payload'];
    }
    return json;
  }

  // ---- node -------------------------------------------------------------------------------------------------

  /// `GET info`
  Future<NodeInfo> info() async => NodeInfo.fromJson(await get('info'));

  /// `GET info/version`
  Future<NodeVersion> version() async =>
      NodeVersion.fromJson(await get('info/version'));

  /// ms since the node started
  Future<int> uptime() async => asInt(await get('info/uptime'));

  /// `GET explorer/info`
  Future<ExplorerInfo> explorerInfo() async =>
      ExplorerInfo.fromJson(await get('explorer/info'));

  // ---- wallet -----------------------------------------------------------------------------------------------

  /// Spendable balance (committed − pending debits) as a decimal string; `'0'` for an unknown address.
  Future<String> balance(String address) async {
    final v = await get('wallets/$address', notFound: '0');
    return v is String ? v : asDecimal(v);
  }

  /// The next nonce to sign with (committed nonce + pending count); `0` for an unknown address.
  Future<int> nonce(String address) async {
    final v = await get('wallets/$address/nonce', notFound: 0);
    return v is int ? v : asInt(v);
  }

  /// Server-side address validation (shape + EIP-55).
  Future<bool> validateAddress(String address) async {
    try {
      await post('wallets/validateAddress', {'address': address});
      return true;
    } on NetworkException {
      rethrow;
    } on JanzeerException {
      return false;
    }
  }

  // ---- transactions -----------------------------------------------------------------------------------------

  /// Submit a signed transaction (HTTP 201). Throws [TxRejectedException] / [NonceMismatchException] on refusal.
  /// The result is the node's echo: a [TransferTx], [TokenTx], [RegisterValidatorTx] or [ExitValidatorTx].
  Future<BaseTx> submit(SignedTx tx) async {
    final v = await post(tx.restPath, tx.toRestBody());
    return switch (tx.fields) {
      TransferFields() => TransferTx.fromJson(v),
      TokenFields() => TokenTx.fromJson(v),
      RegisterValidatorFields() => RegisterValidatorTx.fromJson(v),
      ExitValidatorFields() => ExitValidatorTx.fromJson(v),
    };
  }

  /// transfers (`address` = sender or recipient; `unconfirmed` = the mempool)
  late final TxApi<TransferTx> transfers;

  /// validator registrations (`nodeKey` filter via [TxListQuery.nodeKey])
  late final TxApi<RegisterValidatorTx> validatorTxs;

  /// validator exits
  late final TxApi<ExitValidatorTx> exitValidatorTxs;

  /// token transactions (`tokenId` filter via [TxListQuery.tokenId])
  late final TxApi<TokenTx> tokenTxs;

  /// block rewards (`address` = recipient)
  late final TxApi<RewardTx> rewards;

  /// Execution receipt of a committed transaction (`null` if unknown or still pending).
  Future<Receipt?> receipt(String hash) async {
    final v = await get('transactions/$hash/receipt', notFound: null);
    return v == null ? null : Receipt.fromJson(v);
  }

  // ---- blocks / validators / tokens ---------------------------------------------------------------------------

  /// main + genesis blocks
  late final BlocksApi blocks;

  /// validators
  late final ValidatorsApi validators;

  /// JZT-1 tokens
  late final TokensApi tokens;
}

/// Filters of the transaction lists.
class TxListQuery extends PageQuery {
  /// sender or recipient (transfers, validator txs, exits) / reward recipient
  final String? address;

  /// the mempool instead of the ledger
  final bool unconfirmed;

  /// validator registrations by node key
  final String? nodeKey;

  /// token transactions by token
  final String? tokenId;

  /// Construct.
  const TxListQuery(
      {this.address,
      this.unconfirmed = false,
      this.nodeKey,
      this.tokenId,
      super.page,
      super.size,
      super.sortBy,
      super.sortDirection});

  @override
  Map<String, Object?> toQuery() => {
        ...super.toQuery(),
        'address': address,
        'unconfirmed': unconfirmed ? true : null,
        'nodeKey': nodeKey,
        'tokenId': tokenId
      };
}

/// `client.transfers` / `validatorTxs` / `exitValidatorTxs` / `tokenTxs` / `rewards`.
class TxApi<T extends BaseTx> {
  final JanzeerClient _c;
  final String _path;
  final T Function(Object?) _map;
  TxApi._(this._c, this._path, this._map);

  /// List (paged).
  Future<Page<T>> list([TxListQuery q = const TxListQuery()]) async =>
      Page.from(await _c.get(_path, query: q.toQuery(), notFound: null), _map);

  /// One by hash, or `null`.
  Future<T?> get(String hash) async {
    final v = await _c.get('$_path/$hash', notFound: null);
    return v == null ? null : _map(v);
  }
}

/// `client.blocks`
class BlocksApi {
  BlocksApi._(JanzeerClient c)
      : main = BlockApi<MainBlock>._(c, 'blocks/main', MainBlock.fromJson),
        genesis = BlockApi<GenesisBlock>._(
            c, 'blocks/genesis', GenesisBlock.fromJson);

  /// main blocks (newest first)
  final BlockApi<MainBlock> main;

  /// epoch genesis blocks
  final BlockApi<GenesisBlock> genesis;
}

/// `client.blocks.main` / `client.blocks.genesis`.
class BlockApi<T extends BaseBlock> {
  final JanzeerClient _c;
  final String _path;
  final T Function(Object?) _map;
  BlockApi._(this._c, this._path, this._map);

  /// List (paged, newest first).
  Future<Page<T>> list([PageQuery q = const PageQuery()]) async =>
      Page.from(await _c.get(_path, query: q.toQuery(), notFound: null), _map);

  /// By hash, or `null`.
  Future<T?> get(String hash) => _one('$_path/$hash');

  /// The block before [hash], or `null`.
  Future<T?> previous(String hash) => _one('$_path/$hash/previous');

  /// The block after [hash], or `null`.
  Future<T?> next(String hash) => _one('$_path/$hash/next');

  Future<T?> _one(String p) async {
    final v = await _c.get(p, notFound: null);
    return v == null ? null : _map(v);
  }
}

/// `client.validators`
class ValidatorsApi {
  final JanzeerClient _c;
  ValidatorsApi._(this._c);

  /// every registered validator, registration order
  Future<Page<Validator>> list([PageQuery q = const PageQuery()]) async =>
      Page.from(await _c.get('validators', query: q.toQuery(), notFound: null),
          Validator.fromJson);

  /// the current epoch's producer set
  Future<Page<Validator>> active([PageQuery q = const PageQuery()]) async =>
      Page.from(
          await _c.get('validators/active', query: q.toQuery(), notFound: null),
          Validator.fromJson);

  /// with registration timestamps
  Future<Page<ValidatorView>> view([PageQuery q = const PageQuery()]) async =>
      Page.from(
          await _c.get('validators/view', query: q.toQuery(), notFound: null),
          ValidatorView.fromJson);
}

/// `client.tokens`
class TokensApi {
  final JanzeerClient _c;
  TokensApi._(this._c);

  /// the token registry
  Future<Page<Token>> list([PageQuery q = const PageQuery()]) async =>
      Page.from(await _c.get('tokens', query: q.toQuery(), notFound: null),
          Token.fromJson);

  /// one token, or `null`
  Future<Token?> get(String tokenId) async {
    final v = await _c.get('tokens/$tokenId', notFound: null);
    return v == null ? null : Token.fromJson(v);
  }

  /// holders of a token
  Future<Page<TokenBalance>> holders(String tokenId,
          [PageQuery q = const PageQuery()]) async =>
      Page.from(
          await _c.get('tokens/$tokenId/holders',
              query: q.toQuery(), notFound: null),
          TokenBalance.fromJson);

  /// every token balance of an address
  Future<Page<TokenBalance>> balancesOf(String address,
          [PageQuery q = const PageQuery()]) async =>
      Page.from(
          await _c.get('tokens/balances/$address',
              query: q.toQuery(), notFound: null),
          TokenBalance.fromJson);
}

String _qs(Map<String, Object?>? params) {
  if (params == null) return '';
  final parts = <String>[];
  params.forEach((k, v) {
    if (v != null && v != '') {
      parts.add(
          '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(v.toString())}');
    }
  });
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}
