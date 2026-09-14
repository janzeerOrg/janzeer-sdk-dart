/// Byte helpers shared by the preimage builders (all integers big-endian, like Java's ByteBuffer).
library;

import 'dart:convert';
import 'dart:typed_data';

const String _hex = '0123456789abcdef';

/// bytes → lowercase hex
String bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb
      ..write(_hex[(b >> 4) & 0x0f])
      ..write(_hex[b & 0x0f]);
  }
  return sb.toString();
}

/// Lenient hex → bytes: accepts an optional `0x` prefix and either case.
Uint8List hexToBytes(String hex) {
  final h =
      hex.startsWith('0x') || hex.startsWith('0X') ? hex.substring(2) : hex;
  if (h.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(h)) {
    throw FormatException('invalid hex: $hex');
  }
  final out = Uint8List(h.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// UTF-8 encode
Uint8List utf8ToBytes(String s) => Uint8List.fromList(utf8.encode(s));

/// UTF-8 byte length of a string (memo limit checks).
int utf8Length(String s) => utf8.encode(s).length;

/// Concatenate byte arrays.
Uint8List concatBytes(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (n, p) => n + p.length);
  final out = Uint8List(total);
  var o = 0;
  for (final p in parts) {
    out.setRange(o, o + p.length, p);
    o += p.length;
  }
  return out;
}

/// 8-byte big-endian two's-complement (Java `putLong`).
Uint8List i64be(BigInt value) {
  final out = Uint8List(8);
  var v = value.toUnsigned(64);
  for (var i = 7; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

/// 4-byte big-endian (BIP32 `ser32` / Java `putInt`).
Uint8List ser32(int i) => Uint8List.fromList(
    [(i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff]);

/// `int32(len) ‖ utf8(s)` — the node's length-prefixed string (`TokenPayload`). `null` → empty.
Uint8List lenPrefixed(String? s) {
  final b = utf8ToBytes(s ?? '');
  return concatBytes([ser32(b.length), b]);
}

/// Unsigned big-endian bytes → BigInt.
BigInt bytesToBigInt(Uint8List b) {
  var r = BigInt.zero;
  for (final x in b) {
    r = (r << 8) | BigInt.from(x);
  }
  return r;
}

/// BigInt → fixed-length unsigned big-endian bytes.
Uint8List bigIntToBytes(BigInt v, int len) {
  final out = Uint8List(len);
  var x = v;
  for (var i = len - 1; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x = x >> 8;
  }
  return out;
}

/// bytes → base64
String bytesToBase64(List<int> bytes) => base64.encode(bytes);

/// base64 → bytes
Uint8List base64ToBytes(String b64) => base64.decode(b64);
