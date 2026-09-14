import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('REST error mapping', () {
    test('enveloped nonce mismatch → NonceMismatchException', () {
      final e = restErrorFrom(400, {
        'timestamp': 1,
        'version': '1.1.0',
        'payload': {
          'status': 400,
          'message':
              'Invalid nonce for 0x06e1c0fa9955a700876f8cb0acc7f13fba9fb8ba: expected 4, got 7',
          'type': 'INVALID_NONCE'
        }
      });
      expect(e, isA<NonceMismatchException>());
      expect(e, isA<TxRejectedException>());
      final n = e as NonceMismatchException;
      expect(n.expected, 4);
      expect(n.got, 7);
      expect(n.address, '0x06e1c0fa9955a700876f8cb0acc7f13fba9fb8ba');
      expect(n.type, 'INVALID_NONCE');
      expect(n.httpStatus, 400);
    });
    test('typed rejection / unknown type / validation array / 429 / 404 / sync',
        () {
      final r = restErrorFrom(400, {
        'payload': {
          'status': 400,
          'message': 'Incorrect signature',
          'type': 'INCORRECT_SIGNATURE'
        }
      }) as TxRejectedException;
      expect(r.type, 'INCORRECT_SIGNATURE');
      expect(r.transport, Transport.rest);
      expect(
          (restErrorFrom(400, {
            'payload': {'status': 400, 'message': 'x', 'type': 'SOMETHING_NEW'}
          }) as TxRejectedException)
              .rawType,
          'SOMETHING_NEW');
      final v = restErrorFrom(400, {
        'payload': [
          {'message': 'must not be null'},
          {'message': 'must not be blank'}
        ]
      }) as ValidationException;
      expect(v.messages, ['must not be null', 'must not be blank']);
      final rl = restErrorFrom(
          429, {'status': 429, 'message': 'Rate limit exceeded'},
          retryAfterHeader: '2') as RateLimitedException;
      expect(rl.retryAfter, const Duration(seconds: 2));
      expect(
          restErrorFrom(404, {
            'payload': {'status': 404, 'message': 'nope'}
          }),
          isA<NotFoundException>());
      expect(
          restErrorFrom(400, {
            'payload': {'status': 400, 'message': 'Blockchain is synchronizing'}
          }),
          isA<NotSynchronizedException>());
      expect((restErrorFrom(500, null) as ApiException).status, 500);
    });
  });
  group('RPC error mapping', () {
    test('-32001 with data.type', () {
      expect(
          rpcErrorFrom({
            'code': -32001,
            'message': 'Incorrect signature',
            'data': {'type': 'INCORRECT_SIGNATURE'}
          }),
          isA<TxRejectedException>());
      final n = rpcErrorFrom({
        'code': -32001,
        'message':
            'Invalid nonce for 0x06e1c0fa9955a700876f8cb0acc7f13fba9fb8ba: expected 1, got 5',
        'data': {'type': 'INVALID_NONCE'}
      }) as NonceMismatchException;
      expect(n.expected, 1);
      expect(n.rpcCode, -32001);
      expect(n.transport, Transport.rpc);
    });
    test('other codes', () {
      expect(
          rpcErrorFrom({
            'code': -32602,
            'message': 'bad',
            'data': ['amount: must not be null']
          }),
          isA<RpcInvalidParamsException>());
      expect(rpcErrorFrom({'code': -32000, 'message': 'missing'}),
          isA<RpcNotFoundException>());
      expect(rpcErrorFrom({'code': -32002, 'message': 'sync'}),
          isA<NotSynchronizedException>());
      expect(rpcErrorFrom({'code': -32004, 'message': 'slow down'}),
          isA<RateLimitedException>());
    });
  });
}
