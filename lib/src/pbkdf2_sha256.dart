/// PBKDF2-HMAC-SHA256 written for speed: the two HMAC pad blocks are compressed ONCE, so every round costs exactly two
/// SHA-256 compressions on preallocated 32-bit word buffers. The generic pointycastle derivator needed about 4 s on a
/// desktop and 15-20 s on a phone for the vault's 250 000 rounds; this one is byte-for-byte identical in output
/// (`test/pbkdf2_test.dart` compares the two) and more than ten times faster. Works on the VM, AOT and the web
/// (every intermediate is masked to 32 bits or stored into a `Uint32List`).
library;

import 'dart:typed_data';

final Uint32List _k = Uint32List.fromList(const [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, //
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa,
  0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb,
  0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624,
  0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb,
  0xbef9a3f7, 0xc67178f2,
]);

const List<int> _iv = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c,
  0x1f83d9ab, 0x5be0cd19, //
];

const int _m = 0xFFFFFFFF;

/// One compression: `out = init + rounds(init, w)`. [w] holds the 16 message words in `w[0..15]`; the schedule is
/// expanded in place. [out] may be the same list as [init].
void _compress(Uint32List init, Uint32List w, Uint32List out) {
  for (var i = 16; i < 64; i++) {
    final x = w[i - 15], y = w[i - 2];
    final s0 = ((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3);
    final s1 = ((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10);
    w[i] = w[i - 16] + (s0 & _m) + w[i - 7] + (s1 & _m);
  }
  var a = init[0], b = init[1], c = init[2], d = init[3];
  var e = init[4], f = init[5], g = init[6], h = init[7];
  for (var i = 0; i < 64; i++) {
    final s1 = (((e >>> 6) | (e << 26)) ^
            ((e >>> 11) | (e << 21)) ^
            ((e >>> 25) | (e << 7))) &
        _m;
    final ch = ((e & f) ^ (~e & g)) & _m;
    final t1 = h + s1 + ch + _k[i] + w[i];
    final s0 = (((a >>> 2) | (a << 30)) ^
            ((a >>> 13) | (a << 19)) ^
            ((a >>> 22) | (a << 10))) &
        _m;
    final maj = (a & b) ^ (a & c) ^ (b & c);
    h = g;
    g = f;
    f = e;
    e = (d + t1) & _m;
    d = c;
    c = b;
    b = a;
    a = (t1 + s0 + maj) & _m;
  }
  out[0] = init[0] + a;
  out[1] = init[1] + b;
  out[2] = init[2] + c;
  out[3] = init[3] + d;
  out[4] = init[4] + e;
  out[5] = init[5] + f;
  out[6] = init[6] + g;
  out[7] = init[7] + h;
}

/// SHA-256 of [data] continued from [state] after [prefixLen] already-hashed bytes (a multiple of 64). Returns the
/// eight digest words.
Uint32List _hashFrom(Uint32List state, int prefixLen, Uint8List data) {
  final st = Uint32List.fromList(state);
  final w = Uint32List(64);
  final total = data.length;
  final padded = Uint8List(((total + 9 + 63) ~/ 64) * 64)
    ..setRange(0, total, data);
  padded[total] = 0x80;
  final bits = (prefixLen + total) * 8;
  final view = ByteData.sublistView(padded);
  view.setUint32(padded.length - 8, bits ~/ 0x100000000);
  view.setUint32(padded.length - 4, bits & _m);
  for (var off = 0; off < padded.length; off += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = view.getUint32(off + i * 4);
    }
    _compress(st, w, st);
  }
  return st;
}

/// PBKDF2-HMAC-SHA256 (RFC 8018).
Uint8List pbkdf2HmacSha256(
    Uint8List password, Uint8List salt, int iterations, int dkLen) {
  if (iterations < 1) throw ArgumentError.value(iterations, 'iterations');
  if (dkLen < 1) throw ArgumentError.value(dkLen, 'dkLen');
  final ivState = Uint32List.fromList(_iv);

  // HMAC key block: a key longer than the block is hashed first
  final key = Uint8List(64);
  if (password.length > 64) {
    final d = _hashFrom(ivState, 0, password);
    final kv = ByteData.sublistView(key);
    for (var i = 0; i < 8; i++) {
      kv.setUint32(i * 4, d[i]);
    }
  } else {
    key.setRange(0, password.length, password);
  }
  // the two pad blocks, compressed once
  final w = Uint32List(64);
  final kv = ByteData.sublistView(key);
  final ipad = Uint32List(8), opad = Uint32List(8);
  for (var i = 0; i < 16; i++) {
    w[i] = kv.getUint32(i * 4) ^ 0x36363636;
  }
  _compress(ivState, w, ipad);
  for (var i = 0; i < 16; i++) {
    w[i] = kv.getUint32(i * 4) ^ 0x5c5c5c5c;
  }
  _compress(ivState, w, opad);

  final out = Uint8List(dkLen);
  final outView = ByteData.sublistView(out);
  final u = Uint32List(8), t = Uint32List(8), inner = Uint32List(8);
  final block = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
  final blocks = (dkLen + 31) ~/ 32;

  // a 32-byte message after a 64-byte pad block: the words, the 0x80 marker, zeros, the length (96 bytes = 768 bits)
  void hmacOfDigest(Uint32List msg, Uint32List into) {
    for (var i = 0; i < 8; i++) {
      w[i] = msg[i];
    }
    w[8] = 0x80000000;
    w[9] = 0;
    w[10] = 0;
    w[11] = 0;
    w[12] = 0;
    w[13] = 0;
    w[14] = 0;
    w[15] = 768;
    _compress(ipad, w, inner);
    for (var i = 0; i < 8; i++) {
      w[i] = inner[i];
    }
    w[8] = 0x80000000;
    w[9] = 0;
    w[10] = 0;
    w[11] = 0;
    w[12] = 0;
    w[13] = 0;
    w[14] = 0;
    w[15] = 768;
    _compress(opad, w, into);
  }

  for (var n = 1; n <= blocks; n++) {
    // U1 = HMAC(password, salt ‖ INT(n))
    ByteData.sublistView(block).setUint32(salt.length, n);
    final first = _hashFrom(ipad, 64, block);
    for (var i = 0; i < 8; i++) {
      w[i] = first[i];
    }
    w[8] = 0x80000000;
    for (var i = 9; i < 15; i++) {
      w[i] = 0;
    }
    w[15] = 768;
    _compress(opad, w, u);
    t.setAll(0, u);
    for (var r = 1; r < iterations; r++) {
      hmacOfDigest(u, u);
      t[0] ^= u[0];
      t[1] ^= u[1];
      t[2] ^= u[2];
      t[3] ^= u[3];
      t[4] ^= u[4];
      t[5] ^= u[5];
      t[6] ^= u[6];
      t[7] ^= u[7];
    }
    final base = (n - 1) * 32;
    if (base + 32 <= dkLen) {
      for (var i = 0; i < 8; i++) {
        outView.setUint32(base + i * 4, t[i]);
      }
    } else {
      final last = ByteData(32);
      for (var i = 0; i < 8; i++) {
        last.setUint32(i * 4, t[i]);
      }
      out.setRange(base, dkLen, last.buffer.asUint8List());
    }
  }
  return out;
}
