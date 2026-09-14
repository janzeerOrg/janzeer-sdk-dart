/// Error hierarchy. Every error thrown by the SDK extends [JanzeerException]. A transaction the node refuses is
/// a [TxRejectedException] whichever transport carried it (REST 400 with a `type`, or JSON-RPC `-32001`), and a
/// nonce problem is always a [NonceMismatchException], so callers branch on type, never on strings.
library;

/// Which transport produced an error.
enum Transport {
  /// REST (`/api/v1`)
  rest,

  /// JSON-RPC over HTTP
  rpc,

  /// JSON-RPC over WebSocket
  ws,
}

/// Base class of every SDK error.
class JanzeerException implements Exception {
  /// human-readable message (the node's text when it came from the node)
  final String message;

  /// Construct.
  const JanzeerException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// The node could not be reached, the response was not JSON, or the socket died.
class NetworkException extends JanzeerException {
  /// the underlying error, if any
  final Object? cause;

  /// Construct.
  const NetworkException(super.message, [this.cause]);
}

/// The node refused a transaction at intake (validation / mempool rule).
class TxRejectedException extends JanzeerException {
  /// the node's `ExceptionType` (`INCORRECT_SIGNATURE`, `INVALID_NONCE`, …) or `UNKNOWN`
  final String type;

  /// the type string exactly as received (null when the node sent none)
  final String? rawType;

  /// where it came from
  final Transport transport;

  /// HTTP status (REST)
  final int? httpStatus;

  /// JSON-RPC error code (`-32001`)
  final int? rpcCode;

  /// Construct.
  const TxRejectedException(super.message, String? type, this.transport,
      {this.httpStatus, this.rpcCode})
      : type = type ?? 'UNKNOWN',
        rawType = type;
}

final RegExp _nonceRe =
    RegExp(r'Invalid nonce for (0x[0-9a-fA-F]{40}): expected (\d+), got (\d+)');

/// The transaction's nonce is not the sender's next nonce: refresh it and rebuild.
class NonceMismatchException extends TxRejectedException {
  /// the sender (when the node's message carried it)
  final String? address;

  /// the nonce the node expected
  final int? expected;

  /// the nonce that was sent
  final int? got;

  /// Construct.
  const NonceMismatchException(String message, this.address, this.expected,
      this.got, Transport transport, {int? httpStatus, int? rpcCode})
      : super(message, 'INVALID_NONCE', transport,
            httpStatus: httpStatus, rpcCode: rpcCode);

  /// Build from a node message; `null` when the message is not a nonce mismatch.
  static NonceMismatchException? fromMessage(
      String message, Transport transport,
      {int? httpStatus, int? rpcCode}) {
    final m = _nonceRe.firstMatch(message);
    if (m == null) return null;
    return NonceMismatchException(message, m[1]!.toLowerCase(),
        int.parse(m[2]!), int.parse(m[3]!), transport,
        httpStatus: httpStatus, rpcCode: rpcCode);
  }
}

/// Any other REST error (`{status, message, type?}` payload).
class ApiException extends JanzeerException {
  /// HTTP status
  final int status;

  /// `type` of the error payload, if any
  final String? type;

  /// the parsed error payload (map, list or null)
  final Object? body;

  /// Construct.
  const ApiException(this.status, super.message, {this.type, this.body});
}

/// Request-body validation failed (400 with a list of `{message}`).
class ValidationException extends ApiException {
  /// the field messages
  final List<String> messages;

  /// Construct.
  ValidationException(this.messages, Object? body)
      : super(400, messages.isEmpty ? 'validation failed' : messages.join('; '),
            body: body);
}

/// 404
class NotFoundException extends ApiException {
  /// Construct.
  const NotFoundException(super.status, super.message,
      {super.type, super.body});
}

/// The node is still syncing (REST 400 "Blockchain is synchronizing" / RPC `-32002`); retry shortly.
class NotSynchronizedException extends JanzeerException {
  /// where it came from
  final Transport transport;

  /// Construct.
  const NotSynchronizedException(super.message, this.transport);
}

/// HTTP 429 / RPC `-32004`; [retryAfter] from the `Retry-After` header (default 1 s).
class RateLimitedException extends JanzeerException {
  /// how long to wait
  final Duration retryAfter;

  /// where it came from
  final Transport transport;

  /// Construct.
  const RateLimitedException(super.message, this.retryAfter, this.transport);
}

/// JSON-RPC error that is not a transaction rejection.
class RpcException extends JanzeerException {
  /// JSON-RPC error code
  final int code;

  /// `data` of the error, if any
  final Object? data;

  /// Construct.
  const RpcException(this.code, super.message, [this.data]);
}

/// `-32602` — the SDK sent something the node could not bind (`data` lists field messages).
class RpcInvalidParamsException extends RpcException {
  /// Construct.
  const RpcInvalidParamsException(super.code, super.message, [super.data]);
}

/// `-32000` — block / transaction / token / validator does not exist.
class RpcNotFoundException extends RpcException {
  /// Construct.
  const RpcNotFoundException(super.code, super.message, [super.data]);
}

/// `-32003` — a range or timeout exceeds the server cap.
class RpcLimitException extends RpcException {
  /// Construct.
  const RpcLimitException(super.code, super.message, [super.data]);
}

/// `-32601`
class RpcMethodNotFoundException extends RpcException {
  /// Construct.
  const RpcMethodNotFoundException(super.code, super.message, [super.data]);
}

/// JSON-RPC error codes.
class RpcCodes {
  RpcCodes._();

  /// -32700
  static const int parseError = -32700;

  /// -32600
  static const int invalidRequest = -32600;

  /// -32601
  static const int methodNotFound = -32601;

  /// -32602
  static const int invalidParams = -32602;

  /// -32603
  static const int internal = -32603;

  /// -32000
  static const int notFound = -32000;

  /// -32001 — transaction rejected (`data.type` names the rule)
  static const int rejected = -32001;

  /// -32002
  static const int notSynchronized = -32002;

  /// -32003
  static const int limit = -32003;

  /// -32004
  static const int rateLimited = -32004;
}

/// Map a JSON-RPC `error` object (plain map) to the SDK error hierarchy.
JanzeerException rpcErrorFrom(Map<String, Object?> err,
    [Transport transport = Transport.rpc]) {
  final code = (err['code'] as num?)?.toInt() ?? RpcCodes.internal;
  final message = err['message'] as String? ?? 'RPC error $code';
  final data = err['data'];
  switch (code) {
    case RpcCodes.rejected:
      final type = data is Map ? data['type'] as String? : null;
      return NonceMismatchException.fromMessage(message, transport,
              rpcCode: code) ??
          (type == 'INVALID_NONCE'
              ? NonceMismatchException(message, null, null, null, transport,
                  rpcCode: code)
              : TxRejectedException(message, type, transport, rpcCode: code));
    case RpcCodes.notSynchronized:
      return NotSynchronizedException(message, transport);
    case RpcCodes.rateLimited:
      return RateLimitedException(
          message, const Duration(seconds: 1), transport);
    case RpcCodes.invalidParams:
      return RpcInvalidParamsException(code, message, data);
    case RpcCodes.notFound:
      return RpcNotFoundException(code, message, data);
    case RpcCodes.limit:
      return RpcLimitException(code, message, data);
    case RpcCodes.methodNotFound:
      return RpcMethodNotFoundException(code, message, data);
    default:
      return RpcException(code, message, data);
  }
}

/// Map a non-2xx REST response (plain-value body or null) to the SDK error hierarchy. Rule: if the body has
/// `payload` use it (the envelope wraps errors too); otherwise the body itself (the rate limiter writes flat
/// `{status, message}` before the envelope layer).
JanzeerException restErrorFrom(int status, Object? body,
    {String? retryAfterHeader}) {
  final p = body is Map && body.containsKey('payload') ? body['payload'] : body;
  if (status == 429) {
    final secs = int.tryParse(retryAfterHeader ?? '') ?? 1;
    return RateLimitedException(_msg(p) ?? 'Rate limit exceeded',
        Duration(seconds: secs), Transport.rest);
  }
  if (p is List) {
    return ValidationException(
        p
            .map((x) => x is Map && x['message'] != null
                ? x['message'].toString()
                : x.toString())
            .toList(),
        p);
  }
  final message = _msg(p) ?? 'Request failed ($status)';
  final type = p is Map ? p['type'] as String? : null;
  if (status == 404) {
    return NotFoundException(status, message, type: type, body: p);
  }
  if (status == 400) {
    if (message == 'Blockchain is synchronizing') {
      return NotSynchronizedException(message, Transport.rest);
    }
    final nonce = NonceMismatchException.fromMessage(message, Transport.rest,
        httpStatus: status);
    if (nonce != null) return nonce;
    if (type == 'INVALID_NONCE') {
      return NonceMismatchException(message, null, null, null, Transport.rest,
          httpStatus: status);
    }
    if (type != null) {
      return TxRejectedException(message, type, Transport.rest,
          httpStatus: status);
    }
  }
  return ApiException(status, message, type: type, body: p);
}

String? _msg(Object? p) =>
    p is Map && p['message'] is String && (p['message'] as String).isNotEmpty
        ? p['message'] as String
        : null;
