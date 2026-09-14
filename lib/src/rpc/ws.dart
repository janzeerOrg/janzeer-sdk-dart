/// JSON-RPC 2.0 over the node's WebSocket (`/rpc/ws`): the same methods as HTTP plus live subscriptions
/// (`newBlocks`, `addressActivity`). Uses `package:web_socket_channel` (Dart VM, Flutter and web).
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants.dart';
import '../errors.dart';
import '../json.dart';
import 'methods.dart';
import 'types.dart';

/// Diagnostics events of the WebSocket client.
sealed class WsEvent {
  const WsEvent();
}

/// Connected.
class WsOpen extends WsEvent {
  /// Construct.
  const WsOpen();
}

/// Closed (with reconnect intent).
class WsClosed extends WsEvent {
  /// close code / reason
  final int? code;

  /// reason
  final String? reason;

  /// will reconnect
  final bool willReconnect;

  /// Construct.
  const WsClosed(this.code, this.reason, this.willReconnect);
}

/// Error.
class WsError extends WsEvent {
  /// the error
  final Object error;

  /// Construct.
  const WsError(this.error);
}

/// Subscriptions re-issued after a reconnect.
class WsResubscribed extends WsEvent {
  /// how many
  final int count;

  /// Construct.
  const WsResubscribed(this.count);
}

/// `newBlocks` parameters.
class NewBlocksParams {
  /// replay committed blocks from this height, then stream live ones (exactly-once by height)
  final int? fromHeight;

  /// include the transactions of each block
  final bool includeTransactions;

  /// Construct.
  const NewBlocksParams({this.fromHeight, this.includeTransactions = false});

  Map<String, Object?> _toJson() => {
        if (fromHeight != null) 'fromHeight': fromHeight,
        'includeTransactions': includeTransactions
      };
}

/// An `addressActivity` notification.
class AddressActivityEvent {
  /// block
  final int blockHeight;

  /// block
  final String blockHash;

  /// the final transaction
  final TxView transaction;

  /// Construct.
  const AddressActivityEvent(
      {required this.blockHeight,
      required this.blockHash,
      required this.transaction});
}

/// A live subscription.
class Subscription {
  final _LiveSub _live;
  final JanzeerRpcWs _ws;
  Subscription._(this._live, this._ws);

  /// the node's subscription id (changes after a reconnect)
  String get id => _live.id;

  /// `newBlocks` | `addressActivity`
  String get kind => _live.kind;

  /// Cancel.
  Future<bool> unsubscribe() => _ws._unsubscribe(_live);
}

class _LiveSub {
  String id;
  final String kind;
  final Object params;
  final void Function(Object?) handler;
  _LiveSub(this.id, this.kind, this.params, this.handler);
}

class _Pending {
  final Completer<Object?> completer = Completer();
  final Timer timer;
  _Pending(this.timer);
}

/// JSON-RPC over WebSocket with subscriptions.
class JanzeerRpcWs extends RpcMethods {
  /// `ws://host:7019/rpc/ws`
  final String url;

  final bool _reconnect;
  final Duration _reconnectDelay;
  final Duration _timeout;
  final Duration _connectTimeout;
  final void Function(WsEvent)? _onEvent;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _listener;
  final _pending = <int, _Pending>{};
  final _subs = <String, _LiveSub>{};
  int _id = 0;
  bool _closedByUser = false;
  Duration _backoff;
  Future<void>? _connecting;

  JanzeerRpcWs._(this.url,
      {required bool reconnect,
      required Duration reconnectDelay,
      required Duration timeout,
      required Duration connectTimeout,
      void Function(WsEvent)? onEvent})
      : _reconnect = reconnect,
        _reconnectDelay = reconnectDelay,
        _backoff = reconnectDelay,
        _timeout = timeout,
        _connectTimeout = connectTimeout,
        _onEvent = onEvent;

  /// Open a socket; completes once connected. [url] may be `http(s)://…` (converted) with or without `/rpc/ws`.
  /// With [reconnect] (default true) a dropped socket reconnects with exponential backoff (from [reconnectDelay]
  /// up to 30 s) and every live subscription is re-issued.
  static Future<JanzeerRpcWs> connect(
    String url, {
    bool reconnect = true,
    Duration reconnectDelay = const Duration(seconds: 1),
    Duration timeout = const Duration(seconds: 65),
    Duration connectTimeout = const Duration(seconds: 10),
    void Function(WsEvent)? onEvent,
  }) async {
    final c = JanzeerRpcWs._(normalizeWsUrl(url),
        reconnect: reconnect,
        reconnectDelay: reconnectDelay,
        timeout: timeout,
        connectTimeout: connectTimeout,
        onEvent: onEvent);
    await c._open();
    return c;
  }

  /// true while the socket is open
  bool get connected => _channel != null && _channel!.closeCode == null;

  @override
  Future<Object?> call(String method, [Object? params]) async {
    await _ensureOpen();
    final id = ++_id;
    final p = _Pending(Timer(_timeout, () {
      final x = _pending.remove(id);
      x?.completer.completeError(NetworkException(
          'RPC $method timed out after ${_timeout.inSeconds}s'));
    }));
    _pending[id] = p;
    try {
      _channel!.sink.add(jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        if (params != null) 'params': params
      }));
    } on Object catch (e) {
      p.timer.cancel();
      _pending.remove(id);
      throw NetworkException('send failed', e);
    }
    return p.completer.future;
  }

  /// Stream committed blocks (optionally replaying from `fromHeight`).
  Future<Subscription> subscribeNewBlocks(
          NewBlocksParams params, void Function(BlockView) handler) =>
      _subscribe(
          'newBlocks', params._toJson(), (p) => handler(BlockView.fromJson(p)));

  /// Notify when a final transaction involves any of [addresses] (sender, recipient or token recipient).
  Future<Subscription> subscribeAddressActivity(
      List<String> addresses, void Function(AddressActivityEvent) handler) {
    if (addresses.isEmpty || addresses.length > Limits.watchedAddresses) {
      throw ArgumentError('1–${Limits.watchedAddresses} addresses');
    }
    return _subscribe('addressActivity',
        {'addresses': addresses.map((a) => a.toLowerCase()).toList()}, (p) {
      final o = asObject(p, 'notification');
      handler(AddressActivityEvent(
          blockHeight: asInt(o['blockHeight']),
          blockHash: asString(o['blockHash']),
          transaction: TxView.fromJson(o['transaction'])));
    });
  }

  /// Close the socket; no reconnect. Pending calls fail, subscriptions are dropped.
  Future<void> close() async {
    _closedByUser = true;
    _subs.clear();
    final ch = _channel;
    _channel = null;
    await _listener?.cancel();
    _listener = null;
    await ch?.sink.close(1000, 'client closed');
    _failPending(const NetworkException('socket closed by client'));
  }

  Future<Subscription> _subscribe(
      String kind, Object params, void Function(Object?) handler) async {
    if (_subs.length >= Limits.subscriptionsPerSession) {
      throw StateError(
          'at most ${Limits.subscriptionsPerSession} subscriptions per session');
    }
    final id = asString(
        await call('janzeer_subscribe', {'kind': kind, 'params': params}));
    final live = _LiveSub(id, kind, params, handler);
    _subs[id] = live;
    return Subscription._(live, this);
  }

  Future<bool> _unsubscribe(_LiveSub live) async {
    _subs.remove(live.id);
    if (!connected) return true;
    try {
      return asBool(
          await call('janzeer_unsubscribe', {'subscription': live.id}));
    } on JanzeerException {
      return false;
    }
  }

  Future<void> _ensureOpen() {
    if (connected) return Future.value();
    if (_closedByUser) {
      return Future.error(const NetworkException('socket closed by client'));
    }
    return _open();
  }

  Future<void> _open() {
    final inFlight = _connecting;
    if (inFlight != null) return inFlight;
    final done = Completer<void>();
    _connecting = done.future;
    () async {
      try {
        final ch = WebSocketChannel.connect(Uri.parse(url));
        await ch.ready.timeout(_connectTimeout);
        _channel = ch;
        _backoff = _reconnectDelay;
        _listener = ch.stream.listen(
          (dynamic data) => _onMessage(
              data is String ? data : utf8.decode(data as List<int>)),
          onError: (Object e) => _onEvent?.call(WsError(e)),
          onDone: () => _onClosed(ch),
          cancelOnError: false,
        );
        _onEvent?.call(const WsOpen());
        done.complete();
        unawaited(_resubscribe());
      } on Object catch (e) {
        _onEvent?.call(WsError(e));
        done.completeError(
            NetworkException('WebSocket connect to $url failed: $e', e));
        if (_reconnect && !_closedByUser) _scheduleReconnect();
      } finally {
        _connecting = null;
      }
    }();
    return done.future;
  }

  void _onClosed(WebSocketChannel ch) {
    if (!identical(_channel, ch)) return;
    _channel = null;
    _listener = null;
    final willReconnect = _reconnect && !_closedByUser;
    _onEvent?.call(WsClosed(ch.closeCode, ch.closeReason, willReconnect));
    _failPending(NetworkException('socket closed (${ch.closeCode ?? '?'})'));
    if (willReconnect) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final delay = _backoff;
    _backoff =
        Duration(milliseconds: (_backoff.inMilliseconds * 2).clamp(0, 30000));
    Timer(delay, () {
      if (_closedByUser || connected) return;
      _open().catchError((Object _) {});
    });
  }

  Future<void> _resubscribe() async {
    final old = _subs.values.toList();
    if (old.isEmpty) return;
    _subs.clear();
    var count = 0;
    for (final s in old) {
      try {
        final id = asString(await call(
            'janzeer_subscribe', {'kind': s.kind, 'params': s.params}));
        s.id = id;
        _subs[id] = s;
        count++;
      } on Object catch (e) {
        _onEvent?.call(WsError(e));
      }
    }
    if (count > 0) _onEvent?.call(WsResubscribed(count));
  }

  void _onMessage(String text) {
    Object? msg;
    try {
      msg = parseJson(text);
    } on FormatException {
      return;
    }
    final items = msg is List<Object?> ? msg : [msg];
    for (final m in items) {
      if (m is! Map<String, Object?>) continue;
      if (m['method'] == 'janzeer_subscription' &&
          m['params'] is Map<String, Object?>) {
        final p = m['params'] as Map<String, Object?>;
        final sub = _subs[asOptString(p['subscription'])];
        if (sub != null && p.containsKey('result')) {
          try {
            sub.handler(p['result']);
          } on Object catch (e) {
            _onEvent?.call(WsError(e));
          }
        }
        continue;
      }
      if (m['id'] == null) continue;
      final pending = _pending.remove(asInt(m['id']));
      if (pending == null) continue;
      pending.timer.cancel();
      final err = m['error'];
      if (err != null) {
        pending.completer
            .completeError(rpcErrorFrom(asObject(toPlain(err)), Transport.ws));
      } else {
        pending.completer.complete(m['result']);
      }
    }
  }

  void _failPending(JanzeerException err) {
    for (final p in _pending.values) {
      p.timer.cancel();
      if (!p.completer.isCompleted) p.completer.completeError(err);
    }
    _pending.clear();
  }
}

/// Rewrite an origin / `/api/v1` / `/rpc` url (http or ws scheme) to the `/rpc/ws` endpoint.
String normalizeWsUrl(String url) {
  var u = url
      .trim()
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp('^http:'), 'ws:')
      .replaceFirst(RegExp('^https:'), 'wss:');
  u = u
      .replaceFirst(RegExp(r'/api/v1$'), '')
      .replaceFirst(RegExp(r'/rpc$'), '');
  if (!u.endsWith('/rpc/ws')) u += '/rpc/ws';
  return u;
}
