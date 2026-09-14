/// `package:janzeer_sdk/crypto.dart` — the function-style API of the `janzeer_crypto.dart` module that the
/// Janzeer Flutter wallet used before the SDK existed. Kept so the wallet migrates by changing an import; new
/// code should use `Account`, `TxBuilder` and `SignedTx` from `package:janzeer_sdk/janzeer_sdk.dart`.
library;

import 'dart:typed_data';

import 'src/address.dart';
import 'src/amounts.dart';
import 'src/bytes.dart';
import 'src/constants.dart' as c;
import 'src/hashes.dart';
import 'src/hd.dart';
import 'src/mnemonic.dart';
import 'src/signing.dart';
import 'src/tx/payloads.dart' as p;

export 'src/address.dart'
    show publicKeyToAddress, toChecksumAddress, isChecksumValid;
export 'src/amounts.dart' show toScaledLong;
export 'src/bytes.dart' show bytesToHex, hexToBytes;
export 'src/hd.dart' show mnemonicToSeed;
export 'src/signing.dart' show signHash;
export 'src/tx/payloads.dart'
    show transactionBytes, transferPayload, tokenPayload;

/// `ChainSpec.networkId` (legacy name).
const String kNetworkId = c.networkId;

/// A derived account (legacy shape): private key (hex), compressed public key (hex), address.
class LegacyAccount {
  /// hex
  final String privHex;

  /// hex
  final String pubHex;

  /// canonical lowercase
  final String address;

  /// Construct.
  const LegacyAccount(this.privHex, this.pubHex, this.address);
}

/// Generate a BIP39 mnemonic (12 words by default).
String generateMnemonic({int strength = 128}) =>
    Mnemonic.generate(strength: strength);

/// Wordlist + checksum check.
bool validateMnemonic(String mnemonic) => Mnemonic.validate(mnemonic);

/// seed → `m/0/0/0` account
LegacyAccount accountFromSeed(Uint8List seed) {
  final node = deriveDefault(seed);
  final pub = compressedPublicKey(bytesToBigInt(node.priv));
  return LegacyAccount(
      bytesToHex(node.priv), bytesToHex(pub), publicKeyToAddress(pub));
}

/// mnemonic → account
LegacyAccount accountFromMnemonic(String mnemonic, {String passphrase = ''}) =>
    accountFromSeed(mnemonicToSeed(mnemonic.trim(), passphrase: passphrase));

/// private key (hex) → account
LegacyAccount accountFromPrivateKey(String privHex) {
  final pub = compressedPublicKey(bytesToBigInt(hexToBytes(privHex)));
  return LegacyAccount(privHex, bytesToHex(pub), publicKeyToAddress(pub));
}

/// Validator-registration payload (legacy name).
Uint8List promoterPayload(
        {required Object amount, required String promoterKey}) =>
    p.registerValidatorPayload(amount: amount, validatorKey: promoterKey);

/// Validator-exit payload (legacy name).
Uint8List exitPromoterPayload({required String promoterKey}) =>
    p.exitValidatorPayload(validatorKey: promoterKey);

/// double-SHA256 → hex
String hashBytes(Uint8List bytes) => hashPreimage(bytes);

Map<String, Object?> _sign(String networkId, int timestamp, Object fee,
    int nonce, String senderAddress, String privHex, Uint8List payload) {
  final hash = hashPreimage(p.transactionBytes(
      networkId: networkId,
      timestamp: timestamp,
      fee: fee,
      nonce: nonce,
      senderAddress: senderAddress,
      payload: payload));
  return {'hash': hash, 'signature': signHash(hash, privHex)};
}

/// Build a fully-signed transfer body (ready to POST).
Map<String, Object?> buildSignedTransfer({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required String publicKey,
  required String recipientAddress,
  required Object amount,
  String? data,
  required String privHex,
}) {
  final s = _sign(
      networkId,
      timestamp,
      fee,
      nonce,
      senderAddress,
      privHex,
      p.transferPayload(
          amount: amount, recipientAddress: recipientAddress, data: data));
  return {
    'timestamp': timestamp,
    'fee': normalizeAmount(fee),
    'nonce': nonce,
    'hash': s['hash'],
    'senderAddress': senderAddress,
    'senderSignature': s['signature'],
    'senderPublicKey': publicKey,
    'amount': normalizeAmount(amount),
    'recipientAddress': recipientAddress,
    'data': data,
  };
}

/// Build a signed validator registration body (legacy name).
Map<String, Object?> buildSignedPromoter({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required String publicKey,
  required Object amount,
  required String promoterKey,
  required String privHex,
}) {
  final s = _sign(networkId, timestamp, fee, nonce, senderAddress, privHex,
      promoterPayload(amount: amount, promoterKey: promoterKey));
  return {
    'timestamp': timestamp,
    'fee': normalizeAmount(fee),
    'nonce': nonce,
    'senderAddress': senderAddress,
    'amount': normalizeAmount(amount),
    'validatorKey': promoterKey,
    'hash': s['hash'],
    'senderSignature': s['signature'],
    'senderPublicKey': publicKey,
  };
}

/// Build a signed validator exit body (legacy name).
Map<String, Object?> buildSignedExitPromoter({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required String publicKey,
  required String promoterKey,
  required String privHex,
}) {
  final s = _sign(networkId, timestamp, fee, nonce, senderAddress, privHex,
      exitPromoterPayload(promoterKey: promoterKey));
  return {
    'timestamp': timestamp,
    'fee': normalizeAmount(fee),
    'nonce': nonce,
    'senderAddress': senderAddress,
    'validatorKey': promoterKey,
    'hash': s['hash'],
    'senderSignature': s['signature'],
    'senderPublicKey': publicKey,
  };
}

/// Token op codes (legacy constants).
class TokenOp {
  TokenOp._();

  /// 0
  static const int create = 0;

  /// 1
  static const int mint = 1;

  /// 2
  static const int burn = 2;

  /// 3
  static const int setcap = 3;

  /// 4
  static const int transfer = 4;
}

/// Build a fully-signed TokenTx body. `cap`/`amount` are integer base-unit strings.
Map<String, Object?> buildSignedTokenTx({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required String publicKey,
  required int op,
  String tokenId = '',
  String symbol = '',
  String name = '',
  int decimals = 0,
  String? cap,
  String? amount,
  String? recipient,
  required String privHex,
}) {
  final s = _sign(
      networkId,
      timestamp,
      fee,
      nonce,
      senderAddress,
      privHex,
      p.tokenPayload(
          op: op,
          tokenId: tokenId,
          symbol: symbol,
          name: name,
          decimals: decimals,
          cap: cap,
          amount: amount,
          recipient: recipient));
  return {
    'timestamp': timestamp,
    'fee': normalizeAmount(fee),
    'nonce': nonce,
    'senderAddress': senderAddress,
    'op': op,
    'tokenId': tokenId,
    'symbol': symbol,
    'name': name,
    'decimals': decimals,
    'cap': cap,
    'amount': amount,
    'recipient': recipient,
    'hash': s['hash'],
    'senderSignature': s['signature'],
    'senderPublicKey': publicKey,
  };
}

// ---------------- `compute()` entry points (single sendable argument, plain map out) ----------------

/// mnemonic → `{priv, pub, address}`
Map<String, String> deriveAccountIsolate(String mnemonic) {
  final a = accountFromMnemonic(mnemonic);
  return {'priv': a.privHex, 'pub': a.pubHex, 'address': a.address};
}

/// [buildSignedTransfer] from a primitive map.
Map<String, Object?> buildSignedTransferIsolate(Map<String, Object?> a) =>
    buildSignedTransfer(
      networkId: (a['networkId'] as String?) ?? kNetworkId,
      timestamp: a['timestamp'] as int,
      fee: a['fee'] as Object,
      nonce: a['nonce'] as int,
      senderAddress: a['senderAddress'] as String,
      publicKey: a['publicKey'] as String,
      recipientAddress: a['recipientAddress'] as String,
      amount: a['amount'] as Object,
      data: a['data'] as String?,
      privHex: a['privHex'] as String,
    );

/// [buildSignedPromoter] from a primitive map.
Map<String, Object?> buildSignedPromoterIsolate(Map<String, Object?> a) =>
    buildSignedPromoter(
      networkId: (a['networkId'] as String?) ?? kNetworkId,
      timestamp: a['timestamp'] as int,
      fee: a['fee'] as Object,
      nonce: a['nonce'] as int,
      senderAddress: a['senderAddress'] as String,
      publicKey: a['publicKey'] as String,
      amount: a['amount'] as Object,
      promoterKey: a['promoterKey'] as String,
      privHex: a['privHex'] as String,
    );

/// [buildSignedExitPromoter] from a primitive map.
Map<String, Object?> buildSignedExitPromoterIsolate(Map<String, Object?> a) =>
    buildSignedExitPromoter(
      networkId: (a['networkId'] as String?) ?? kNetworkId,
      timestamp: a['timestamp'] as int,
      fee: a['fee'] as Object,
      nonce: a['nonce'] as int,
      senderAddress: a['senderAddress'] as String,
      publicKey: a['publicKey'] as String,
      promoterKey: a['promoterKey'] as String,
      privHex: a['privHex'] as String,
    );

/// [buildSignedTokenTx] from a primitive map.
Map<String, Object?> buildSignedTokenTxIsolate(Map<String, Object?> a) =>
    buildSignedTokenTx(
      networkId: (a['networkId'] as String?) ?? kNetworkId,
      timestamp: a['timestamp'] as int,
      fee: a['fee'] as Object,
      nonce: a['nonce'] as int,
      senderAddress: a['senderAddress'] as String,
      publicKey: a['publicKey'] as String,
      op: a['op'] as int,
      tokenId: (a['tokenId'] as String?) ?? '',
      symbol: (a['symbol'] as String?) ?? '',
      name: (a['name'] as String?) ?? '',
      decimals: (a['decimals'] as int?) ?? 0,
      cap: a['cap'] as String?,
      amount: a['amount'] as String?,
      recipient: a['recipient'] as String?,
      privHex: a['privHex'] as String,
    );
