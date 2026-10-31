/// BIP39 entropy ↔ mnemonic (English wordlist, SHA-256 checksum), implemented here so the SDK carries no
/// third-party mnemonic dependency. Only the word encoding is BIP39; the seed is Janzeer's own (`hd.dart`).
library;

import 'dart:math';
import 'dart:typed_data';

import 'hashes.dart';
import 'wordlist_english.dart';

/// Index of each word; built once on first use.
final Map<String, int> _wordIndex = {
  for (var i = 0; i < englishWordlist.length; i++) englishWordlist[i]: i,
};

/// Entropy (16, 20, 24, 28 or 32 bytes) → 12, 15, 18, 21 or 24 words.
String bip39EntropyToMnemonic(Uint8List entropy) {
  if (entropy.length < 16 || entropy.length > 32 || entropy.length % 4 != 0) {
    throw ArgumentError.value(
        entropy.length, 'entropy', 'must be 16, 20, 24, 28 or 32 bytes');
  }
  final checksumBits = entropy.length ~/ 4; // ENT / 32
  final hash = sha256(entropy);
  // Bit stream: entropy then the first ENT/32 bits of its SHA-256; read 11 bits per word.
  final words = <String>[];
  var acc = 0, nBits = 0;
  void push(int byte, int bits) {
    acc = (acc << bits) | (byte >> (8 - bits));
    nBits += bits;
    if (nBits >= 11) {
      nBits -= 11;
      words.add(englishWordlist[(acc >> nBits) & 0x7ff]);
      acc &= (1 << nBits) - 1;
    }
  }

  for (final b in entropy) {
    push(b, 8);
  }
  var left = checksumBits;
  for (var i = 0; left > 0; i++) {
    final take = left >= 8 ? 8 : left;
    push(hash[i], take);
    left -= take;
  }
  return words.join(' ');
}

/// Words (already normalized: lower case, single spaces) → entropy bytes. Throws [ArgumentError] on a word outside
/// the list, a word count that is not 12/15/18/21/24, or a checksum mismatch.
Uint8List bip39MnemonicToEntropy(String mnemonic) {
  final words = mnemonic.split(' ');
  if (words.length % 3 != 0 || words.length < 12 || words.length > 24) {
    throw ArgumentError.value(
        words.length, 'mnemonic', 'word count must be 12, 15, 18, 21 or 24');
  }
  final totalBits = words.length * 11;
  final checksumBits = totalBits ~/ 33;
  final entropyBits = totalBits - checksumBits;
  final entropy = Uint8List(entropyBits ~/ 8);
  var acc = 0, nBits = 0, out = 0, checksum = 0;
  for (final w in words) {
    final idx = _wordIndex[w];
    if (idx == null) {
      throw ArgumentError.value(
          w, 'mnemonic', 'word is not in the BIP39 English list');
    }
    acc = (acc << 11) | idx;
    nBits += 11;
    while (nBits >= 8 && out < entropy.length) {
      nBits -= 8;
      entropy[out++] = (acc >> nBits) & 0xff;
      acc &= (1 << nBits) - 1;
    }
  }
  // What remains in acc are the checksum bits.
  checksum = acc & ((1 << checksumBits) - 1);
  final expected = sha256(entropy)[0] >> (8 - checksumBits);
  if (checksum != expected) {
    throw ArgumentError.value(mnemonic, 'mnemonic', 'checksum mismatch');
  }
  return entropy;
}

/// Fresh entropy from `Random.secure()` encoded as a mnemonic; [strength] in bits (128 → 12 words … 256 → 24).
String bip39Generate({int strength = 128, Random? random}) {
  if (strength % 32 != 0 || strength < 128 || strength > 256) {
    throw ArgumentError.value(
        strength, 'strength', 'must be 128, 160, 192, 224 or 256');
  }
  final rng = random ?? Random.secure();
  final entropy = Uint8List(strength ~/ 8);
  for (var i = 0; i < entropy.length; i++) {
    entropy[i] = rng.nextInt(256);
  }
  return bip39EntropyToMnemonic(entropy);
}
