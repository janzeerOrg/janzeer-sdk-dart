import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

String env(Object? payload) => jsonEncode(
    {'timestamp': 1757800000000, 'version': '1.1.0', 'payload': payload});

void main() {
  test('normalizes the base url and unwraps the envelope losslessly', () async {
    final c = JanzeerClient('http://node:7019',
        httpClient: MockClient((r) async => r.url.path ==
                '/api/v1/wallets/0xabc'
            ? http.Response(
                '{"timestamp":1,"version":"1.1.0","payload":123456789.12345678}',
                200)
            : http.Response(env({'status': 404, 'message': 'no'}), 404)));
    expect(c.baseUrl, 'http://node:7019/api/v1/');
    expect(await c.balance('0xabc'), '123456789.12345678');
    expect(c.lastEnvelope?.version, '1.1.0');
    expect(await c.balance('0xnew'), '0');
    expect(await c.nonce('0xnew'), 0);
    expect(await c.transfers.get('dead'), isNull);
  });
  test('maps pages, typed models and query params', () async {
    late Uri seen;
    final c =
        JanzeerClient('http://node:7019', httpClient: MockClient((r) async {
      seen = r.url;
      if (r.url.path == '/api/v1/tokens') {
        return http.Response(
            '{"timestamp":1,"version":"1.1.0","payload":{"total":1,"page":0,"pageSize":5,"totalPages":1,"list":[{"tokenId":"ab","symbol":"JZT","name":"T","decimals":0,"cap":340282366920938463463374607431768211456,"totalSupply":1,"issuer":"0x1"}]}}',
            200);
      }
      return http.Response(
          env({
            'total': 1,
            'list': [
              {
                'hash': 'h',
                'timestamp': 1,
                'fee': 0.01,
                'senderAddress': '0xa',
                'senderSignature': 's',
                'senderPublicKey': 'p',
                'status': true,
                'amount': 1.5,
                'recipientAddress': '0xb',
                'data': null,
                'results': null,
                'blockHash': null
              }
            ]
          }),
          200);
    }));
    final page = await c.tokens.list(const PageQuery(size: 5));
    expect(page.list.single.cap,
        BigInt.parse('340282366920938463463374607431768211456'));
    expect(seen.queryParameters['size'], '5');
    final t = await c.transfers
        .list(const TxListQuery(address: '0xa', unconfirmed: true));
    expect(t.list.single.fee, '0.01');
    expect(t.list.single.amount, '1.5');
    expect(t.list.single.isFinal, isFalse);
    expect(seen.queryParameters['unconfirmed'], 'true');
  });
  test('submit posts the body and maps rejections', () async {
    final acct = Account.fromPrivateKey(
        '6deadaf98b65c46612b57db1551da40d79ed6a759f23f9cf137612f8ef238efc');
    final tx = acct.signTx(TxBuilder.transfer(
        from: acct.address,
        to: '0x598b1301acef3baba6ce25e38dd17b723f7b98b1',
        amount: '1',
        nonce: 3,
        timestamp: 1));
    var n = 0;
    final c =
        JanzeerClient('http://node:7019', httpClient: MockClient((r) async {
      expect(r.url.path, '/api/v1/transactions/transfers');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['hash'], tx.hash);
      expect(body['senderSignature'], tx.signature);
      expect(body['amount'], '1');
      n++;
      if (n == 1) {
        return http.Response(
            env({
              'status': 400,
              'message': 'Invalid nonce for ${acct.address}: expected 4, got 3',
              'type': 'INVALID_NONCE'
            }),
            400);
      }
      if (n == 2) {
        return http.Response(
            env({
              'status': 400,
              'message': 'Incorrect signature',
              'type': 'INCORRECT_SIGNATURE'
            }),
            400);
      }
      if (n == 3) {
        return http.Response(
            env([
              {'message': 'amount must not be null'}
            ]),
            400);
      }
      return http.Response(
          env({...body, 'status': true, 'blockHash': null}), 201);
    }));
    await expectLater(
        c.submit(tx),
        throwsA(isA<NonceMismatchException>()
            .having((e) => e.expected, 'expected', 4)
            .having((e) => e.got, 'got', 3)));
    await expectLater(
        c.submit(tx),
        throwsA(isA<TxRejectedException>()
            .having((e) => e.type, 'type', 'INCORRECT_SIGNATURE')));
    await expectLater(c.submit(tx), throwsA(isA<ValidationException>()));
    final ok = await c.submit(tx) as TransferTx;
    expect(ok.hash, tx.hash);
    expect(ok.amount, '1');
  });
  test('info carries the chain identity and tolerates an older node', () async {
    var c = JanzeerClient('http://node:7019',
        httpClient: MockClient((r) async => http.Response(env(jsonDecode('{"nodeKey":"02ab","host":"","port":9199,"networkId":"janzeer-testnet","genesisHash":"88bae6976718ea46f7ca92655df5743a3d46b9267c66670579c065138c8ee910","chainSpecDigest":"cc","version":"0.1.0","apiVersion":"1.1.0","protocolVersion":"3.2.0","syncStatus":"SYNCHRONIZED","faucet":true}')), 200)));
    final info = await c.info();
    expect(info.networkId, 'janzeer-testnet');
    expect(info.genesisHash, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(info.version, '0.1.0');
    expect(info.faucet, isTrue);
    c = JanzeerClient('http://node:7019',
        httpClient: MockClient((r) async => http.Response(env(jsonDecode('{"nodeKey":"02ab","host":"","port":9199}')), 200)));
    final old = await c.info();
    expect(old.networkId, 'janzeer');
    expect(old.faucet, isFalse);
    expect(old.genesisHash, '');
  });
  test('retries once on 429 honouring Retry-After', () async {
    var n = 0;
    final c = JanzeerClient('http://node:7019',
        httpClient: MockClient((r) async => ++n == 1
            ? http.Response(
                jsonEncode({'status': 429, 'message': 'Rate limit exceeded'}),
                429,
                headers: {'retry-after': '0'})
            : http.Response(env(42), 200)));
    expect(await c.uptime(), 42);
    expect(n, 2);
  });

  test('follows one redirect for POST too (http → https behind nginx)', () async {
    // package:http follows redirects only for GET/HEAD; a base URL typed as http:// in front of an https-only
    // node answered 301 to every POST — the Flutter wallet's "request failed 301" (online test 2026-09-23).
    final seen = <String>[];
    final c = JanzeerClient('http://node.example', httpClient: MockClient((r) async {
      seen.add('${r.method} ${r.url}');
      if (r.url.scheme == 'http') {
        return http.Response('', 301, headers: {'location': r.url.replace(scheme: 'https').toString()});
      }
      expect(r.method, 'POST');
      expect(jsonDecode(r.body), {'x': 1});
      return http.Response(jsonEncode({'timestamp': 1, 'version': '1', 'payload': {'ok': true}}), 200,
          headers: {'content-type': 'application/json'});
    }));
    final r = await c.post('transactions/transfers', {'x': 1});
    expect(r, {'ok': true});
    expect(seen, ['POST http://node.example/api/v1/transactions/transfers', 'POST https://node.example/api/v1/transactions/transfers']);
  });
}
