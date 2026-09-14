/// BIP39 English mnemonics (standard wordlist + checksum); only the seed derivation is Janzeer-specific.
library;

import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;

import 'bytes.dart';
import 'hd.dart';

/// Mnemonic helpers.
class Mnemonic {
  Mnemonic._();

  /// A fresh mnemonic: 12 words (128-bit, default), 15 (160), 18 (192), 21 (224) or 24 (256).
  static String generate({int strength = 128}) =>
      bip39.generateMnemonic(strength: strength);

  /// Wordlist membership + checksum. Client-side UX only — the node never sees a mnemonic.
  static bool validate(String mnemonic) {
    try {
      return bip39.validateMnemonic(normalize(mnemonic));
    } on Object {
      return false;
    }
  }

  /// Normalize whitespace and case so equivalent phrases derive the same seed.
  static String normalize(String mnemonic) =>
      mnemonic.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

  /// Janzeer seed (PBKDF2-HMAC-SHA512, salt `@_Janzeer_Blockchain_@` + passphrase) — NOT the BIP39 standard seed.
  static Uint8List toSeed(String mnemonic, {String passphrase = ''}) =>
      mnemonicToSeed(normalize(mnemonic), passphrase: passphrase);

  /// Entropy bytes → mnemonic (for hardware / dice-generated entropy).
  static String fromEntropy(Uint8List entropy) =>
      bip39.entropyToMnemonic(bytesToHex(entropy));

  /// Mnemonic → entropy bytes.
  static Uint8List toEntropy(String mnemonic) =>
      hexToBytes(bip39.mnemonicToEntropy(normalize(mnemonic)));
}
