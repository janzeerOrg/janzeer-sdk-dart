import 'dart:convert';
import 'dart:io';

import 'package:janzeer_sdk/janzeer_sdk.dart';

/// Demonstrates a 3-step offline signing flow.
/// Note: The nonce must be the account's next nonce at the time of broadcast.
Future<void> main() async {
  final env = Platform.environment;
  final client = JanzeerClient(env['JANZEER_NODE_URL'] ?? 'http://localhost:7019');
  final rpc = JanzeerRpc(env['JANZEER_RPC_URL'] ?? 'http://localhost:7019');
  final account = Account.fromMnemonic(env['JANZEER_E2E_MNEMONIC'] ??
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
  final filePath = env['JANZEER_OFFLINE_FILE'] ?? 'offline_tx.json';

  // 1. Online: Read network state
  final networkId = (await client.info()).networkId;
  final nonce = await client.nonce(account.address);
  print('Step 1: Read networkId=$networkId, nonce=$nonce');

  // 2. Offline: Sign and save to file
  final tx = account.signTx(TxBuilder.transfer(
    from: account.address,
    to: '0x598b1301acef3baba6ce25e38dd17b723f7b98b1',
    amount: '0.1',
    nonce: nonce,
  ), networkId: networkId);

  final txData = {
    'type': tx.type.wireName,
    'body': tx.toRestBody(),
  };
  File(filePath).writeAsStringSync(jsonEncode(txData));
  print('Step 2: Signed offline and saved to $filePath');

  // 3. Online: Broadcast
  final raw = jsonDecode(File(filePath).readAsStringSync());
  final type = TxType.values.firstWhere((t) => t.wireName == raw['type']);
  
  final hash = await rpc.sendRawTransaction(type, raw['body']);
  print('Step 3: Broadcasted $hash');

  final fin = await waitForFinality(rpc, hash);
  print('Finalized in block ${fin.blockHeight}');
  
  File(filePath).deleteSync();
  client.close();
  rpc.close();
}
