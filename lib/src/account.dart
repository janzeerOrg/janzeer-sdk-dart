/// A signing identity: private key → public key → address. The node never sees the private key.
library;

import 'dart:math';
import 'dart:typed_data';

import 'address.dart';
import 'bytes.dart';
import 'hd.dart';
import 'mnemonic.dart';
import 'signing.dart';
import 'tx/types.dart';

/// A wallet account.
class Account {
  final Uint8List _priv;

  /// compressed secp256k1 public key, hex (66 chars)
  final String publicKeyHex;

  /// canonical lowercase address
  final String address;

  /// EIP-55 display form of [address]
  final String checksumAddress;

  Account._(this._priv)
      : publicKeyHex = bytesToHex(compressedPublicKey(bytesToBigInt(_priv))),
        address = publicKeyToAddress(compressedPublicKey(bytesToBigInt(_priv))),
        checksumAddress = toChecksumAddress(
            publicKeyToAddress(compressedPublicKey(bytesToBigInt(_priv))));

  /// Wallet account from a BIP39 mnemonic (Janzeer seed, path `m/0/0/0`).
  factory Account.fromMnemonic(String mnemonic, {String passphrase = ''}) {
    if (!Mnemonic.validate(mnemonic)) {
      throw const FormatException(
          'invalid mnemonic (unknown word or bad checksum)');
    }
    return Account.fromSeed(Mnemonic.toSeed(mnemonic, passphrase: passphrase));
  }

  /// Account from a 64-byte seed (default path `m/0/0/0`; any non-hardened path accepted).
  factory Account.fromSeed(Uint8List seed, {String? path}) {
    final node = path == null ? deriveDefault(seed) : derivePath(seed, path);
    return Account._(node.priv);
  }

  /// Account from a raw private key (hex, optional `0x`).
  factory Account.fromPrivateKey(String privateKeyHex) {
    if (!isValidPrivateKey(privateKeyHex)) {
      throw const FormatException('invalid secp256k1 private key');
    }
    return Account._(hexToBytes(privateKeyHex));
  }

  /// A fresh random key (not mnemonic-backed; prefer `Mnemonic.generate()` + [Account.fromMnemonic] for users).
  factory Account.random() {
    final rng = Random.secure();
    while (true) {
      final b =
          Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
      final d = bytesToBigInt(b);
      if (d > BigInt.zero && d < curveOrder) return Account._(b);
    }
  }

  /// The private key as hex. Handle with care: never log or send it.
  String get privateKeyHex => bytesToHex(_priv);

  /// RFC-6979 low-S DER signature (Base64) over a 32-byte digest given as hex.
  String sign(String hashHex) => signHash(hashHex, privateKeyHex);

  /// Verify a signature made by this account.
  bool verify(String hashHex, String signatureBase64) =>
      verifyHash(hashHex, signatureBase64, publicKeyHex);

  /// Hash and sign an [UnsignedTx]. Throws if the tx names another sender.
  SignedTx signTx(UnsignedTx tx) {
    if (tx.senderAddress != address) {
      throw ArgumentError(
          'tx sender ${tx.senderAddress} is not this account ($address)');
    }
    return tx.withSignature(sign(tx.hash()), publicKeyHex);
  }

  @override
  String toString() => 'Account($checksumAddress)';
}
