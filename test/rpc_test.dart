import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('JanzeerRpc (HTTP)', () {
    Map<String, Object?> one(Map<String, dynamic> r) {
      final id = r['id'];
      switch (r['method']) {
        case 'janzeer_getNonce':
          return {'jsonrpc': '2.0', 'id': id, 'result': 7};
        case 'janzeer_getBalance':
          return (r['params'] as Map)['address'] == '0x12'
              ? {
                  'jsonrpc': '2.0',
                  'id': id,
                  'error': {'code': -32602, 'message': "Invalid address '0x12'"}
                }
              : {'jsonrpc': '2.0', 'id': id, 'result': '__BAL__'};
        case 'janzeer_getTransactionByHash':
          return {
            'jsonrpc': '2.0',
            'id': id,
            'result': {
              'hash': (r['params'] as Map)['hash'],
              'type': null,
              'status': 'UNKNOWN'
            }
          };
        case 'janzeer_getToken':
          return {
            'jsonrpc': '2.0',
            'id': id,
            'error': {'code': -32000, 'message': 'Token not found'}
          };
        case 'janzeer_sendTransfer':
          return {
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': -32001,
              'message':
                  'Invalid nonce for 0x06e1c0fa9955a700876f8cb0acc7f13fba9fb8ba: expected 1, got 5',
              'data': {'type': 'INVALID_NONCE'}
            }
          };
        default:
          return {
            'jsonrpc': '2.0',
            'id': id,
            'error': {'code': -32601, 'message': 'Method not found'}
          };
      }
    }

    final client = MockClient((req) async {
      final body = jsonDecode(req.body);
      final out = body is List
          ? body.map((x) => one(x as Map<String, dynamic>)).toList()
          : one(body as Map<String, dynamic>);
      // raw text so the 17-digit balance is not rounded by the test itself
      return http.Response(
          jsonEncode(out).replaceAll('"__BAL__"', '1000.00000001'), 200);
    });
    test('normalizes url, maps results losslessly and errors by code',
        () async {
      final rpc = JanzeerRpc('http://node:7019/api/v1', httpClient: client);
      expect(rpc.url, 'http://node:7019/rpc');
      expect(await rpc.getNonce('0xa'), 7);
      expect(await rpc.getBalance('0xa'), '1000.00000001');
      await expectLater(
          rpc.getBalance('0x12'), throwsA(isA<RpcInvalidParamsException>()));
      await expectLater(
          rpc.getToken('x'), throwsA(isA<RpcNotFoundException>()));
      await expectLater(
          rpc.sendTransfer({}),
          throwsA(isA<NonceMismatchException>()
              .having((e) => e.expected, 'expected', 1)));
      expect((await rpc.getTransactionByHash('ab')).status, TxStatus.unknown);
    });
    test('batch keeps order and isolates failures', () async {
      final rpc = JanzeerRpc('http://node:7019', httpClient: client);
      final r = await rpc.batch([
        const BatchRequest('janzeer_getNonce', {'address': '0xa'}),
        const BatchRequest('janzeer_nope'),
        const BatchRequest('janzeer_getBalance', {'address': '0xa'})
      ]);
      expect(r[0].ok, isTrue);
      expect(r[1].ok, isFalse);
      expect(r[2].result.toString(), '1000.00000001');
    });
  });

  group('JanzeerRpcWs', () {
    late HttpServer server;
    final sockets = <WebSocket>[];
    var subs = 0;
    setUpAll(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        sockets.add(ws);
        ws.listen((dynamic raw) {
          final m = jsonDecode(raw as String) as Map<String, dynamic>;
          String reply(Object? result, [Map<String, Object?>? error]) =>
              jsonEncode({
                'jsonrpc': '2.0',
                'id': m['id'],
                if (error != null) 'error': error else 'result': result
              });
          switch (m['method']) {
            case 'janzeer_getTip':
              ws.add(reply({
                'type': 'main',
                'height': 10,
                'hash': 'h',
                'previousHash': 'p',
                'timestamp': 1,
                'producer': 'k',
                'signature': 's',
                'epochIndex': 1,
                'transactionsCount': 0
              }));
            case 'janzeer_subscribe':
              final id = 'sub${++subs}';
              final kind = (m['params'] as Map)['kind'];
              ws.add(reply(id));
              Future<void>.delayed(const Duration(milliseconds: 20), () {
                if (ws.readyState != WebSocket.open) return;
                ws.add(jsonEncode({
                  'jsonrpc': '2.0',
                  'method': 'janzeer_subscription',
                  'params': {
                    'subscription': id,
                    'kind': kind,
                    'result': kind == 'newBlocks'
                        ? {
                            'type': 'main',
                            'height': 11,
                            'hash': 'h2',
                            'previousHash': 'h',
                            'timestamp': 2,
                            'producer': 'k',
                            'signature': 's'
                          }
                        : {
                            'blockHeight': 11,
                            'blockHash': 'h2',
                            'transaction': {
                              'hash': 'tx1',
                              'type': 'transfer',
                              'status': 'FINAL',
                              'amount': 1.25
                            }
                          }
                  }
                }));
              });
            case 'janzeer_unsubscribe':
              ws.add(reply(true));
            default:
              ws.add(
                  reply(null, {'code': -32601, 'message': 'Method not found'}));
          }
        });
      });
    });
    tearDownAll(() => server.close(force: true));

    test('calls, subscribes, receives notifications, resubscribes after a drop',
        () async {
      final events = <String>[];
      final ws = await JanzeerRpcWs.connect('http://localhost:${server.port}',
          reconnectDelay: const Duration(milliseconds: 50),
          onEvent: (e) => events.add(e.runtimeType.toString()));
      expect(ws.url, 'ws://localhost:${server.port}/rpc/ws');
      expect((await ws.getTip()).height, 10);
      final blocks = <int>[];
      final sub = await ws.subscribeNewBlocks(
          const NewBlocksParams(fromHeight: 1), (b) => blocks.add(b.height));
      final activity = <String>[];
      await ws.subscribeAddressActivity(
          ['0xABC'],
          (ev) =>
              activity.add('${ev.transaction.hash}:${ev.transaction.amount}'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(blocks, [11]);
      expect(activity, ['tx1:1.25']);
      final firstId = sub.id;
      for (final s in sockets) {
        await s.close();
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(ws.connected, isTrue);
      expect(events, contains('WsResubscribed'));
      expect(sub.id, isNot(firstId));
      expect(blocks.length, greaterThanOrEqualTo(2));
      expect(await sub.unsubscribe(), isTrue);
      await ws.close();
      expect(ws.connected, isFalse);
    });
  });
}
