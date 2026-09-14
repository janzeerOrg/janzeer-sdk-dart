/// ECDSA secp256k1 exactly as `SignatureUtils` / `ECKey`: RFC-6979 deterministic, canonical low-S, DER, Base64,
/// over the RAW 32-byte digest.
library;

import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'bytes.dart';

final ECDomainParameters _secp256k1 = ECDomainParameters('secp256k1');

/// secp256k1 group order `n`.
final BigInt curveOrder = _secp256k1.n;

/// Compressed (33-byte) public key for a private scalar.
Uint8List compressedPublicKey(BigInt d) => (_secp256k1.G * d)!.getEncoded(true);

/// Compressed public key (hex) from a private key (hex).
String privateToPublic(String privateKeyHex) =>
    bytesToHex(compressedPublicKey(bytesToBigInt(hexToBytes(privateKeyHex))));

/// True when [privateKeyHex] is a valid secp256k1 scalar (32 bytes, 0 < k < n).
bool isValidPrivateKey(String privateKeyHex) {
  try {
    final b = hexToBytes(privateKeyHex);
    if (b.length != 32) return false;
    final d = bytesToBigInt(b);
    return d > BigInt.zero && d < curveOrder;
  } on FormatException {
    return false;
  }
}

/// Sign a 32-byte digest (hex) with a private key (hex): RFC-6979 (HMAC-SHA256 k), low-S, DER, Base64.
String signHash(String hashHex, String privateKeyHex) {
  final d = bytesToBigInt(hexToBytes(privateKeyHex));
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
    ..init(true, PrivateKeyParameter(ECPrivateKey(d, _secp256k1)));
  final sig = signer.generateSignature(hexToBytes(hashHex)) as ECSignature;
  var s = sig.s;
  if (s.compareTo(curveOrder >> 1) > 0) s = curveOrder - s; // canonical low-S
  return bytesToBase64(derEncode(sig.r, s));
}

/// Verify a Base64 DER signature over a digest (hex) with a compressed public key (hex).
bool verifyHash(String hashHex, String signatureBase64, String publicKeyHex) {
  try {
    final (r, s) = derDecode(base64ToBytes(signatureBase64));
    if (s > (curveOrder >> 1)) return false; // the node rejects high-S
    final q = _secp256k1.curve.decodePoint(hexToBytes(publicKeyHex));
    if (q == null) return false;
    final verifier = ECDSASigner(null, HMac(SHA256Digest(), 64))
      ..init(false, PublicKeyParameter(ECPublicKey(q, _secp256k1)));
    return verifier.verifySignature(hexToBytes(hashHex), ECSignature(r, s));
  } on Object {
    return false;
  }
}

Uint8List _minimalBe(BigInt v) {
  if (v == BigInt.zero) return Uint8List.fromList([0]);
  final bytes = <int>[];
  var x = v;
  while (x > BigInt.zero) {
    bytes.insert(0, (x & BigInt.from(0xff)).toInt());
    x = x >> 8;
  }
  return Uint8List.fromList(bytes);
}

Uint8List _derInt(BigInt v) {
  var mag = _minimalBe(v);
  if ((mag[0] & 0x80) != 0) mag = Uint8List.fromList([0, ...mag]);
  return Uint8List.fromList([0x02, mag.length, ...mag]);
}

/// DER SEQUENCE of two INTEGERs (r, s). secp256k1 signatures are < 128 bytes, so lengths fit one byte.
Uint8List derEncode(BigInt r, BigInt s) {
  final ri = _derInt(r);
  final si = _derInt(s);
  return Uint8List.fromList([0x30, ri.length + si.length, ...ri, ...si]);
}

/// Decode a DER SEQUENCE(INTEGER r, INTEGER s). Throws [FormatException] on malformed input.
(BigInt, BigInt) derDecode(Uint8List der) {
  if (der.length < 8 || der[0] != 0x30 || der[1] != der.length - 2) {
    throw const FormatException('bad DER sequence');
  }
  var i = 2;
  BigInt readInt() {
    if (der[i] != 0x02) throw const FormatException('bad DER integer');
    final len = der[i + 1];
    final v =
        bytesToBigInt(Uint8List.fromList(der.sublist(i + 2, i + 2 + len)));
    i += 2 + len;
    return v;
  }

  final r = readInt();
  final s = readInt();
  if (i != der.length) throw const FormatException('trailing DER bytes');
  return (r, s);
}
