/// `package:janzeer_sdk/vault.dart` — the mnemonic (or any secret) at rest, sealed with a password.
///
/// Also carries the static `Vault.encrypt` / `Vault.decrypt` map API and the `compute()` entry points that the
/// Janzeer Flutter wallet used before the SDK existed.
library;

import 'src/vault.dart';

export 'src/vault.dart';

/// Map-based compatibility API (`{v, salt, iv, ct}` maps in and out).
class Vault {
  Vault._();

  /// Seal [secret] under [password] → JSON-safe map.
  static Map<String, dynamic> encrypt(String secret, String password) =>
      encryptVault(secret, password).toJson();

  /// Open a map blob with [password]. Throws [VaultException] on a wrong password.
  static String decrypt(Map<String, dynamic> vault, String password) =>
      decryptVault(VaultBlob.fromJson(vault), password);
}

/// `compute()` entry point: `[mnemonic, password]` → the encrypted vault map.
Map<String, dynamic> vaultEncryptIsolate(List<String> args) =>
    Vault.encrypt(args[0], args[1]);

/// `compute()` entry point: `[vaultMap, password]` → the decrypted secret. Throws on a wrong password.
String vaultDecryptIsolate(List<dynamic> args) =>
    Vault.decrypt(Map<String, dynamic>.from(args[0] as Map), args[1] as String);
