// Create a JZT-1 token, then move some units. Token amounts are integer base units (BigInt / int / digit string).
// Only a VALIDATOR's wallet may create tokens; on the dev net node-up.sh exports the first anchor's wallet.
import 'dart:io';

import 'package:janzeer_sdk/janzeer_sdk.dart';

Future<void> main() async {
  final env = Platform.environment;
  final issuerMnemonic = env['JANZEER_E2E_VALIDATOR_MNEMONIC'];
  if (issuerMnemonic == null) {
    print(
        'JANZEER_E2E_VALIDATOR_MNEMONIC not set — token CREATE needs a validator wallet; skipping');
    return;
  }
  final client =
      JanzeerClient(env['JANZEER_NODE_URL'] ?? 'http://localhost:7019');
  final rpc = JanzeerRpc(env['JANZEER_RPC_URL'] ?? 'http://localhost:7019');
  final issuer = Account.fromMnemonic(issuerMnemonic);
  final holder = env['JANZEER_E2E_RECIPIENT'] ??
      '0x598b1301acef3baba6ce25e38dd17b723f7b98b1';

  final create = issuer.signTx(TxBuilder.token.create(
      from: issuer.address,
      symbol: 'DEMO',
      name: 'Demo Token',
      decimals: 2,
      cap: 1000000,
      amount: 500000,
      nonce: await client.nonce(issuer.address)));
  final created = await sendAndWait(rpc, create, submitVia: client);
  final tokenId =
      created.tokenId!; // for CREATE the tokenId is the transaction hash
  print('token $tokenId created in block ${created.blockHeight}');
  final def = await client.tokens.get(tokenId);
  print(
      'definition ${def?.symbol} ${def?.name} decimals ${def?.decimals} cap ${def?.cap} supply ${def?.totalSupply}');

  final move = issuer.signTx(TxBuilder.token.transfer(
      from: issuer.address,
      tokenId: tokenId,
      amount: 12345,
      recipient: holder,
      nonce: await client.nonce(issuer.address)));
  await sendAndWait(rpc, move, submitVia: client);
  for (final h in (await client.tokens.holders(tokenId)).list) {
    print('holder ${h.holder} balance ${h.balance}');
  }
  client.close();
  rpc.close();
}
