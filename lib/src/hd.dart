/// Key derivation — BIP39/BIP32-SHAPED but with Janzeer's own constants (`SeedConstant.SALT`), so stock
/// bip32 libraries will NOT reproduce it. Mirrors `SeedCalculator`, `ExtendedKey`, `DerivationKeysHelper`.
library;

import 'dart:typed_data';

import 'bytes.dart';
import 'hashes.dart';
import 'signing.dart';

/// Used BOTH as the PBKDF2 salt base (instead of BIP39's `"mnemonic"`) AND as the root HMAC key.
const String hdSalt = '@_Janzeer_Blockchain_@';

/// The only derivation path wallets use; all three levels are non-hardened.
const String defaultPath = 'm/0/0/0';

/// An extended private key node: 32-byte private key + 32-byte chain code.
class HdNode {
  /// 32-byte private key
  final Uint8List priv;

  /// 32-byte chain code
  final Uint8List chainCode;

  /// Construct from raw parts.
  const HdNode(this.priv, this.chainCode);
}

/// `SeedCalculator.calculateSeed` — PBKDF2-HMAC-SHA512, 2048 rounds, 64 bytes, salt `hdSalt + passphrase`.
/// Inputs are used as given (BIP39 English phrases are ASCII; NFKD-normalize non-ASCII passphrases yourself).
Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) =>
    pbkdf2Sha512(
        utf8ToBytes(mnemonic), utf8ToBytes(hdSalt + passphrase), 2048, 64);

/// `ExtendedKey.root` — `I = HMAC-SHA512(key = hdSalt, msg = seed)`; `IL` = private key, `IR` = chain code.
HdNode seedToMasterKey(Uint8List seed) {
  final i = hmacSha512(utf8ToBytes(hdSalt), seed);
  return HdNode(Uint8List.fromList(i.sublist(0, 32)),
      Uint8List.fromList(i.sublist(32, 64)));
}

/// `ExtendedKey.getChild` — standard BIP32 non-hardened CKDpriv (`index` < 2^31).
HdNode deriveChild(HdNode node, int index) {
  if (index < 0 || index >= 0x80000000) {
    throw RangeError('non-hardened index expected');
  }
  final pub = compressedPublicKey(bytesToBigInt(node.priv));
  final i = hmacSha512(node.chainCode, concatBytes([pub, ser32(index)]));
  final child = (bytesToBigInt(Uint8List.fromList(i.sublist(0, 32))) +
          bytesToBigInt(node.priv)) %
      curveOrder;
  return HdNode(
      bigIntToBytes(child, 32), Uint8List.fromList(i.sublist(32, 64)));
}

/// Derive a path like `m/0/0/0` (non-hardened segments only).
HdNode derivePath(Uint8List seed, [String path = defaultPath]) {
  final parts = path.split('/');
  if (parts.first != 'm') throw RangeError('path must start with m/: $path');
  var node = seedToMasterKey(seed);
  for (final p in parts.skip(1)) {
    if (p.endsWith("'") || p.endsWith('h') || p.endsWith('H')) {
      throw RangeError('hardened derivation is not part of the Janzeer scheme');
    }
    node = deriveChild(node, int.parse(p));
  }
  return node;
}

/// The wallet key: seed → `m/0/0/0`.
HdNode deriveDefault(Uint8List seed) => derivePath(seed);
