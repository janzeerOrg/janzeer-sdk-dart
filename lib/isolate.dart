/// `package:janzeer_sdk/isolate.dart` — run the CPU-heavy operations (PBKDF2 ×2048 / ×250 000, secp256k1) off
/// the main isolate with `Isolate.run`. Dart VM / Flutter mobile & desktop only (not web — there the plain
/// synchronous calls are the only option).
library;

import 'dart:isolate';

import 'src/account.dart';
import 'src/tx/types.dart';
import 'src/vault.dart';

/// `Account.fromMnemonic` in a background isolate (returns the private key hex; rebuild the account with
/// `Account.fromPrivateKey` — the [Account] object itself is not sendable).
Future<Account> deriveAccountInBackground(String mnemonic,
    {String passphrase = ''}) async {
  final priv = await Isolate.run(() =>
      Account.fromMnemonic(mnemonic, passphrase: passphrase).privateKeyHex);
  return Account.fromPrivateKey(priv);
}

/// `encryptVault` in a background isolate.
Future<VaultBlob> encryptVaultInBackground(String secret, String password) =>
    Isolate.run(() {
      final b = encryptVault(secret, password);
      return b.toJson();
    }).then(VaultBlob.fromJson);

/// `decryptVault` in a background isolate (throws [VaultException] on a wrong password).
Future<String> decryptVaultInBackground(VaultBlob blob, String password) {
  final m = blob.toJson();
  return Isolate.run(() => decryptVault(VaultBlob.fromJson(m), password));
}

/// Sign a transaction in a background isolate. Returns the signature (Base64 DER); attach it with
/// `tx.withSignature(signature, account.publicKeyHex)`.
Future<String> signInBackground(UnsignedTx tx, String privateKeyHex) {
  final hash = tx.hash();
  return Isolate.run(() => Account.fromPrivateKey(privateKeyHex).sign(hash));
}
