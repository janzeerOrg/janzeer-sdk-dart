// The conformance flow (sdk_conformance/e2e/SPEC.md) against a running network. Skipped unless JANZEER_NODE_URL is
// set — start the local net with `sdk_conformance/e2e/node-up.sh` and `eval "$(… --env)"`.
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

void main() {
  final nodeUrl = Platform.environment['JANZEER_NODE_URL'];
  final rpcUrl = Platform.environment['JANZEER_RPC_URL'] ?? nodeUrl;
  final wsUrl = Platform.environment['JANZEER_WS_URL'] ?? nodeUrl;
  final mnemonic = Platform.environment['JANZEER_E2E_MNEMONIC'] ??
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  final recipient = Platform.environment['JANZEER_E2E_RECIPIENT'] ??
      '0x598b1301acef3baba6ce25e38dd17b723f7b98b1';

  test('e2e: SPEC.md flow (Dart)', () async {
    final client = JanzeerClient(nodeUrl!);
    final rpc = JanzeerRpc(rpcUrl!);

    final acct = Account.fromMnemonic(mnemonic); // 1
    expect(acct.address, '0x06e1c0fa9955a700876f8cb0acc7f13fba9fb8ba');

    final v = await client.version(); // 2
    expect(v.version, SpecVersion.node);
    expect(client.lastEnvelope?.version, SpecVersion.api);

    final a0 = await rpc.getAccount(acct.address); // 3
    expect(compareAmounts(a0.balance, '0'), 1);
    final nonce = a0.nextNonce;

    final ws = await JanzeerRpcWs.connect(wsUrl!); // 4
    final seen = <AddressActivityEvent>[];
    final sub = await ws.subscribeAddressActivity([recipient], seen.add);
    expect(sub.id, matches(RegExp(r'^[0-9a-f]{16}$')));

    final tx = acct.signTx(TxBuilder.transfer(
        from: acct.address,
        to: recipient,
        amount: '1.25',
        fee: '0.01',
        data: 'sdk-e2e-dart',
        nonce: nonce)); // 5
    expect(acct.verify(tx.hash, tx.signature), isTrue);

    final submitted = await client.submit(tx); // 6
    expect(submitted.hash, tx.hash);

    final again = await rpc.send(tx); // 7
    expect(again.hash, tx.hash);
    expect((await rpc.getAccount(acct.address)).pendingCount,
        lessThanOrEqualTo(1));

    expect([TxStatus.pending, TxStatus.finalized],
        contains((await rpc.getTransactionByHash(tx.hash)).status)); // 8

    final fin = await waitForFinality(ws, tx.hash,
        timeout: const Duration(minutes: 2)); // 9
    expect(fin.status, TxStatus.finalized);
    expect(fin.blockHeight, greaterThan(0));
    expect(fin.receipt?.successful, isTrue);

    final expected = subAmounts(subAmounts(a0.balance, '1.25'), '0.01'); // 10
    expect(subAmounts(await client.balance(acct.address), '0'), expected);

    final deadline = DateTime.now().add(const Duration(seconds: 60)); // 11
    while (!seen.any((e) => e.transaction.hash == tx.hash) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(seen.firstWhere((e) => e.transaction.hash == tx.hash).blockHeight,
        fin.blockHeight);
    expect(await sub.unsubscribe(), isTrue);
    await ws.close();

    final gap = acct.signTx(TxBuilder.transfer(
        from: acct.address,
        to: recipient,
        amount: '1',
        nonce: nonce + 10)); // 12
    await expectLater(
        client.submit(gap),
        throwsA(isA<NonceMismatchException>()
            .having((e) => e.type, 'type', 'INVALID_NONCE')
            .having((e) => e.got, 'got', nonce + 10)));
    await expectLater(
        rpc.send(gap),
        throwsA(isA<NonceMismatchException>()
            .having((e) => e.rpcCode, 'rpcCode', -32001)));

    final next = await client.nonce(acct.address); // 13
    final good = acct.signTx(TxBuilder.transfer(
        from: acct.address, to: recipient, amount: '1', nonce: next));
    final forged = TxBuilder.transfer(
            from: acct.address, to: recipient, amount: '2', nonce: next)
        .withSignature(good.signature, acct.publicKeyHex);
    await expectLater(
        client.submit(forged),
        throwsA(isA<TxRejectedException>()
            .having((e) => e.type, 'type', 'INCORRECT_SIGNATURE')));

    await expectLater(rpc.getBalance('0x12'),
        throwsA(isA<RpcInvalidParamsException>())); // 14
    client.close();
    rpc.close();
  }, skip: nodeUrl == null ? 'JANZEER_NODE_URL not set' : false);
}
