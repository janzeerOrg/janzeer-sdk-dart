import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:janzeer_sdk/src/bytes.dart';
import 'package:janzeer_sdk/src/hashes.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

/// The generic derivator the SDK used before: the reference the fast implementation must equal.
Uint8List reference(
        Uint8List password, Uint8List salt, int iterations, int dkLen) =>
    (PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
          ..init(Pbkdf2Parameters(salt, iterations, dkLen)))
        .process(password);

Uint8List ascii(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  test('published PBKDF2-HMAC-SHA256 vectors', () {
    expect(bytesToHex(pbkdf2Sha256(ascii('password'), ascii('salt'), 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    expect(bytesToHex(pbkdf2Sha256(ascii('password'), ascii('salt'), 2, 32)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    expect(bytesToHex(pbkdf2Sha256(ascii('password'), ascii('salt'), 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    expect(
        bytesToHex(pbkdf2Sha256(ascii('passwordPASSWORDpassword'),
            ascii('saltSALTsaltSALTsaltSALTsaltSALTsalt'), 4096, 40)),
        '348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9');
  });

  test('equals the generic derivator for every input shape', () {
    final rng = Random(20261005);
    Uint8List bytes(int n) =>
        Uint8List.fromList(List<int>.generate(n, (_) => rng.nextInt(256)));
    // password shorter than, equal to and longer than the 64-byte block; salts across the padding boundaries
    for (final pwLen in [0, 1, 8, 55, 63, 64, 65, 100, 200]) {
      for (final saltLen in [0, 1, 16, 51, 52, 55, 56, 59, 60, 64, 100, 130]) {
        for (final (iterations, dkLen) in [
          (1, 32),
          (2, 20),
          (3, 33),
          (17, 64),
          (50, 70)
        ]) {
          final pw = bytes(pwLen), salt = bytes(saltLen);
          expect(pbkdf2Sha256(pw, salt, iterations, dkLen),
              reference(pw, salt, iterations, dkLen),
              reason: 'pw=$pwLen salt=$saltLen c=$iterations dk=$dkLen');
        }
      }
    }
  });

  test('the vault parameters (250 000 rounds, 16-byte salt, 32-byte key)', () {
    final pw = ascii('correct horse battery staple'),
        salt = Uint8List.fromList(List<int>.generate(16, (i) => i * 7));
    final sw = Stopwatch()..start();
    final fast = pbkdf2Sha256(pw, salt, 250000, 32);
    final fastMs = sw.elapsedMilliseconds;
    expect(fast, reference(pw, salt, 250000, 32));
    printOnFailure('fast derivation took $fastMs ms');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
