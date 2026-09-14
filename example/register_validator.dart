// Register (and later exit) a validator node. The 2000 JNZ deposit is NON-refundable — this example only builds
// and prints the transactions unless RUN_FOR_REAL=1.
import 'dart:io';

import 'package:janzeer_sdk/janzeer_sdk.dart';

Future<void> main() async {
  final env = Platform.environment;
  final client =
      JanzeerClient(env['JANZEER_NODE_URL'] ?? 'http://localhost:7019');
  final wallet = Account.fromMnemonic(env['JANZEER_E2E_MNEMONIC'] ??
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
  final validatorKey = env['VALIDATOR_KEY'] ??
      (await client.info()).nodeKey; // the node's public key from GET info

  final nonce = await client.nonce(wallet.address);
  final register = wallet.signTx(TxBuilder.registerValidator(
      from: wallet.address, validatorKey: validatorKey, nonce: nonce));
  print(
      'register ${validatorKey.substring(0, 12)}… fee $validatorFee deposit $validatorDeposit ${register.toRestBody()}');
  final exit = wallet.signTx(TxBuilder.exitValidator(
      from: wallet.address, validatorKey: validatorKey, nonce: nonce + 1));
  print('exit (pipelined nonce) ${exit.toRestBody()}');
  if (env['RUN_FOR_REAL'] == '1') {
    print('submitted ${(await client.submit(register)).hash}');
  } else {
    print('dry run — set RUN_FOR_REAL=1 to submit the registration');
  }
  client.close();
}
