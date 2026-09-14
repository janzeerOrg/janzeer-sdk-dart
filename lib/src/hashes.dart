/// Hash primitives exactly as the node uses them (`HashUtils`).
library;

import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'bytes.dart';

/// SHA-256
Uint8List sha256(Uint8List data) => SHA256Digest().process(data);

/// `HashUtils.doubleSha256` — the transaction hash function.
Uint8List doubleSha256(Uint8List data) => sha256(sha256(data));

/// Double-SHA256 as lowercase hex — what the node calls the transaction `hash`.
String hashPreimage(Uint8List preimage) => bytesToHex(doubleSha256(preimage));

/// Keccak-256 (the Ethereum variant, NOT NIST SHA3-256) — addresses and the EIP-55 checksum.
Uint8List keccak256(Uint8List data) => KeccakDigest(256).process(data);

/// HMAC-SHA512
Uint8List hmacSha512(Uint8List key, Uint8List msg) {
  final mac = HMac(SHA512Digest(), 128)..init(KeyParameter(key));
  return mac.process(msg);
}

/// PBKDF2-HMAC-SHA512
Uint8List pbkdf2Sha512(
    Uint8List password, Uint8List salt, int iterations, int dkLen) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128))
    ..init(Pbkdf2Parameters(salt, iterations, dkLen));
  return kdf.process(password);
}

/// PBKDF2-HMAC-SHA256
Uint8List pbkdf2Sha256(
    Uint8List password, Uint8List salt, int iterations, int dkLen) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, dkLen));
  return kdf.process(password);
}
