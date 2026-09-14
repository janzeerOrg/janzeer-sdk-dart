// Keep a mnemonic at rest encrypted under a password (what the Janzeer wallets store).
import 'dart:convert';

import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:janzeer_sdk/vault.dart';

void main() {
  final mnemonic = Mnemonic.generate();
  final blob = encryptVault(mnemonic, 'correct horse battery staple');
  print('stored blob ${jsonEncode(blob.toJson())}');
  final restored = decryptVault(blob, 'correct horse battery staple');
  print(
      'same wallet: ${Account.fromMnemonic(restored).address == Account.fromMnemonic(mnemonic).address}');
  try {
    decryptVault(blob, 'wrong');
  } on VaultException catch (e) {
    print('wrong password → ${e.runtimeType}');
  }
}
