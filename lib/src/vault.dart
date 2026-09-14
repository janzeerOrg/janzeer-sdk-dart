/// A secret at rest, sealed with a password: PBKDF2-HMAC-SHA256 (250 000 rounds) → AES-256-GCM. The blob is
/// byte-compatible with the TypeScript and Kotlin SDK vaults (conformance fixture `vault-fixture.json`).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'hashes.dart';

/// blob format version
const int vaultVersion = 1;

/// PBKDF2 rounds
const int vaultIterations = 250000;

/// The persisted blob `{v, salt, iv, ct}` (all base64).
class VaultBlob {
  /// 16-byte salt
  final String salt;

  /// 12-byte IV
  final String iv;

  /// ciphertext ‖ 16-byte GCM tag
  final String ct;

  /// Construct.
  const VaultBlob({required this.salt, required this.iv, required this.ct});

  /// From a stored map (throws [VaultException] on an unsupported version).
  factory VaultBlob.fromJson(Map<String, dynamic> m) {
    if (m['v'] != vaultVersion) {
      throw VaultException('unsupported vault version ${m['v']}');
    }
    return VaultBlob(
        salt: m['salt'] as String,
        iv: m['iv'] as String,
        ct: m['ct'] as String);
  }

  /// JSON-safe map.
  Map<String, dynamic> toJson() =>
      {'v': vaultVersion, 'salt': salt, 'iv': iv, 'ct': ct};
}

/// Wrong password or corrupted blob.
class VaultException implements Exception {
  /// message
  final String message;

  /// Construct.
  const VaultException(this.message);

  @override
  String toString() => 'VaultException: $message';
}

final Random _rng = Random.secure();

Uint8List _random(int n) =>
    Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

Uint8List _key(String password, Uint8List salt) => pbkdf2Sha256(
    Uint8List.fromList(utf8.encode(password)), salt, vaultIterations, 32);

/// Seal [secret] under [password]. Randomized (fresh salt + IV each call).
VaultBlob encryptVault(String secret, String password) {
  final salt = _random(16);
  final iv = _random(12);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
        true,
        AEADParameters(
            KeyParameter(_key(password, salt)), 128, iv, Uint8List(0)));
  final ct = cipher.process(Uint8List.fromList(utf8.encode(secret)));
  return VaultBlob(
      salt: base64.encode(salt), iv: base64.encode(iv), ct: base64.encode(ct));
}

/// Open a blob. Throws [VaultException] when the password is wrong or the blob was tampered with.
String decryptVault(VaultBlob blob, String password) {
  try {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false,
          AEADParameters(KeyParameter(_key(password, base64.decode(blob.salt))),
              128, base64.decode(blob.iv), Uint8List(0)));
    return utf8.decode(cipher.process(base64.decode(blob.ct)));
  } on VaultException {
    rethrow;
  } on Object catch (e) {
    throw VaultException('wrong password or corrupted vault ($e)');
  }
}
