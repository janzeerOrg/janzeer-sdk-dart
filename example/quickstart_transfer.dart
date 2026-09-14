// Send 1.25 JNZ and wait until it is final. Needs a node with a funded wallet (sdk_conformance/e2e/node-up.sh).
import 'dart:io';

import 'package:janzeer_sdk/janzeer_sdk.dart';

Future<void> main() async {
  final env = Platform.environment;
  final client =
      JanzeerClient(env['JANZEER_NODE_URL'] ?? 'http://localhost:7019');
  final rpc = JanzeerRpc(env['JANZEER_RPC_URL'] ?? 'http://localhost:7019');
  final account = Account.fromMnemonic(env['JANZEER_E2E_MNEMONIC'] ??
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
  final to = env['JANZEER_E2E_RECIPIENT'] ??
      '0x598b1301acef3baba6ce25e38dd17b723f7b98b1';

  print(
      'wallet ${account.checksumAddress} balance ${formatJnz(await client.balance(account.address))}');

  final tx = account.signTx(TxBuilder.transfer(
      from: account.address,
      to: to,
      amount: '1.25',
      data: 'hello from janzeer_sdk',
      nonce: await client.nonce(account.address)));
  await client.submit(tx);
  print('submitted ${tx.hash}');

  final fin = await waitForFinality(rpc, tx.hash);
  print(
      'FINAL in block ${fin.blockHeight} receipt ok: ${fin.receipt?.successful}');
  print('balance now ${formatJnz(await client.balance(account.address))}');
  client.close();
  rpc.close();
}
