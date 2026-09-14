import 'dart:convert';
import 'dart:io';

import 'package:janzeer_sdk/vault.dart';
import 'package:test/test.dart';

void main() {
  final f =
      jsonDecode(File('test/vectors/vault-fixture.json').readAsStringSync())
          as Map<String, dynamic>;
  test('decrypts the cross-SDK fixture', () {
    final blob =
        VaultBlob.fromJson(Map<String, dynamic>.from(f['blob'] as Map));
    expect(decryptVault(blob, f['password'] as String), f['secret']);
    expect(() => decryptVault(blob, f['wrongPassword'] as String),
        throwsA(isA<VaultException>()));
    expect(
        Vault.decrypt(Map<String, dynamic>.from(f['blob'] as Map),
            f['password'] as String),
        f['secret']);
  });
  test('round-trips a fresh blob', () {
    final blob = encryptVault('top secret', 'pw');
    expect(decryptVault(blob, 'pw'), 'top secret');
    final tampered = VaultBlob(
        salt: blob.salt,
        iv: blob.iv,
        ct: '${blob.ct.substring(0, blob.ct.length - 4)}AAAA');
    expect(() => decryptVault(tampered, 'pw'), throwsA(isA<VaultException>()));
    expect(
        vaultDecryptIsolate([
          vaultEncryptIsolate(['m', 'p']),
          'p'
        ]),
        'm');
  });
}
