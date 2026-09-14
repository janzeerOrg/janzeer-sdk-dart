/// Transaction builders. Each returns an [UnsignedTx]; sign with `account.signTx(tx)`. The builders validate
/// what the node validates at intake (amounts, memo size, exact validator fees) so a mistake fails locally.
library;

import 'dart:typed_data';

import '../address.dart';
import '../amounts.dart';
import '../bytes.dart';
import '../constants.dart' as c;
import 'payloads.dart';
import 'types.dart';

final RegExp _keyRe = RegExp(r'^0[23][0-9a-fA-F]{64}$');
final RegExp _tokenIdRe = RegExp(r'^[0-9a-fA-F]{64}$');
final RegExp _unitsRe = RegExp(r'^\d+$');

/// Transaction builders. `nonce` comes from the node (`client.nonce(address)` / `rpc.getAccount(address).nextNonce`).
class TxBuilder {
  TxBuilder._();

  /// A native-coin transfer. Fee defaults to [c.minFee]. With a memo ([data]) the amount may be below [c.minTransfer].
  static UnsignedTx transfer({
    required String from,
    required String to,
    required Object amount,
    String? data,
    required int nonce,
    int? timestamp,
    Object? fee,
    String? networkId,
  }) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.minFee,
        networkId: networkId);
    final a = normalizeAmount(amount);
    if (!isValidAmount(a) || a.startsWith('-')) {
      throw ArgumentError(
          'amount must be a decimal with ≤ 8 fractional digits, got $a');
    }
    final memo = (data == null || data.isEmpty) ? null : data;
    if (memo != null && utf8Length(memo) > c.maxMemoBytes) {
      throw ArgumentError('memo exceeds ${c.maxMemoBytes} UTF-8 bytes');
    }
    if (memo == null && compareAmounts(a, c.minTransfer) < 0) {
      throw ArgumentError(
          'amount must be ≥ ${c.minTransfer} unless the transfer carries a memo');
    }
    final fields = TransferFields(
        amount: a, recipientAddress: normalizeAddress(to), data: memo);
    return b.build(
        c.TxType.transfer,
        fields,
        transferPayload(
            amount: a, recipientAddress: fields.recipientAddress, data: memo));
  }

  /// Register a validator node: pays exactly [c.validatorFee] and locks the NON-REFUNDABLE [c.validatorDeposit].
  static UnsignedTx registerValidator({
    required String from,
    required String validatorKey,
    Object? amount,
    required int nonce,
    int? timestamp,
    Object? fee,
    String? networkId,
  }) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.validatorFee,
        networkId: networkId);
    if (compareAmounts(b.fee, c.validatorFee) != 0) {
      throw ArgumentError(
          'validator registration fee must be exactly ${c.validatorFee}');
    }
    final a = normalizeAmount(amount ?? c.validatorDeposit);
    if (compareAmounts(a, c.validatorDeposit) != 0) {
      throw ArgumentError(
          'validator deposit must be exactly ${c.validatorDeposit}');
    }
    final fields = RegisterValidatorFields(
        amount: a, validatorKey: _checkKey(validatorKey));
    return b.build(c.TxType.registerValidator, fields,
        registerValidatorPayload(amount: a, validatorKey: fields.validatorKey));
  }

  /// Gracefully exit a validator (removed at the next epoch; the deposit stays locked).
  static UnsignedTx exitValidator(
      {required String from,
      required String validatorKey,
      required int nonce,
      int? timestamp,
      Object? fee,
      String? networkId}) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.minFee,
        networkId: networkId);
    final fields = ExitValidatorFields(validatorKey: _checkKey(validatorKey));
    return b.build(c.TxType.exitValidator, fields,
        exitValidatorPayload(validatorKey: fields.validatorKey));
  }

  /// JZT-1 token operations. Token amounts are integer base units ([BigInt], [int] or digit [String]).
  static const token = TokenTxBuilder._();
}

/// Token builders (`TxBuilder.token.*`).
class TokenTxBuilder {
  const TokenTxBuilder._();

  /// Create a token; the new `tokenId` is the transaction hash. Fee is exactly [c.tokenCreateFee]. Sender must be a validator wallet.
  UnsignedTx create({
    required String from,
    required String symbol,
    required String name,
    int decimals = 0,
    Object? cap,
    Object? amount,
    required int nonce,
    int? timestamp,
    Object? fee,
    String? networkId,
  }) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.tokenCreateFee,
        networkId: networkId);
    if (compareAmounts(b.fee, c.tokenCreateFee) != 0) {
      throw ArgumentError(
          'token create fee must be exactly ${c.tokenCreateFee}');
    }
    if (decimals < 0 || decimals > 18) {
      throw ArgumentError('decimals must be 0–18');
    }
    if (symbol.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('symbol and name are required');
    }
    return _tokenTx(
        b,
        TokenFields(
            op: c.TokenOp.create,
            symbol: symbol.trim(),
            name: name.trim(),
            decimals: decimals,
            cap: cap == null ? null : _units(cap, 'cap'),
            amount: amount == null ? null : _units(amount, 'amount')));
  }

  /// Mint units (issuer only); [recipient] defaults to the sender.
  UnsignedTx mint(
      {required String from,
      required String tokenId,
      required Object amount,
      String? recipient,
      required int nonce,
      int? timestamp,
      Object? fee,
      String? networkId}) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.minFee,
        networkId: networkId);
    return _tokenTx(
        b,
        TokenFields(
            op: c.TokenOp.mint,
            tokenId: _checkTokenId(tokenId),
            amount: _units(amount, 'amount'),
            recipient: recipient == null ? null : normalizeAddress(recipient)));
  }

  /// Burn the sender's units (issuer only).
  UnsignedTx burn(
      {required String from,
      required String tokenId,
      required Object amount,
      required int nonce,
      int? timestamp,
      Object? fee,
      String? networkId}) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.minFee,
        networkId: networkId);
    return _tokenTx(
        b,
        TokenFields(
            op: c.TokenOp.burn,
            tokenId: _checkTokenId(tokenId),
            amount: _units(amount, 'amount')));
  }

  /// Change the cap (issuer only).
  UnsignedTx setCap(
      {required String from,
      required String tokenId,
      required Object cap,
      required int nonce,
      int? timestamp,
      Object? fee,
      String? networkId}) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.minFee,
        networkId: networkId);
    return _tokenTx(
        b,
        TokenFields(
            op: c.TokenOp.setCap,
            tokenId: _checkTokenId(tokenId),
            cap: _units(cap, 'cap')));
  }

  /// Move units to [recipient].
  UnsignedTx transfer(
      {required String from,
      required String tokenId,
      required Object amount,
      required String recipient,
      required int nonce,
      int? timestamp,
      Object? fee,
      String? networkId}) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ?? c.minFee,
        networkId: networkId);
    return _tokenTx(
        b,
        TokenFields(
            op: c.TokenOp.transfer,
            tokenId: _checkTokenId(tokenId),
            amount: _units(amount, 'amount'),
            recipient: normalizeAddress(recipient)));
  }

  /// Escape hatch: any op with raw fields (no validation beyond the payload layout).
  UnsignedTx raw(
      {required String from,
      required TokenFields fields,
      required int nonce,
      int? timestamp,
      Object? fee,
      String? networkId}) {
    final b = _base(
        from: from,
        nonce: nonce,
        timestamp: timestamp,
        fee: fee ??
            (fields.op == c.TokenOp.create ? c.tokenCreateFee : c.minFee),
        networkId: networkId);
    return _tokenTx(b, fields);
  }
}

class _Base {
  final String? networkId;
  final int timestamp;
  final String fee;
  final int nonce;
  final String senderAddress;
  const _Base(
      this.networkId, this.timestamp, this.fee, this.nonce, this.senderAddress);
  UnsignedTx build(c.TxType type, TxFields fields, Uint8List payload) =>
      UnsignedTx(
          type: type,
          networkId: networkId,
          timestamp: timestamp,
          fee: fee,
          nonce: nonce,
          senderAddress: senderAddress,
          fields: fields,
          payload: payload);
}

_Base _base(
    {required String from,
    required int nonce,
    int? timestamp,
    required Object fee,
    String? networkId}) {
  final f = normalizeAmount(fee);
  if (!isValidAmount(f) || compareAmounts(f, c.minFee) < 0) {
    throw ArgumentError('fee must be a decimal ≥ ${c.minFee}, got $f');
  }
  if (nonce < 0) {
    throw ArgumentError('nonce must be a non-negative integer, got $nonce');
  }
  return _Base(networkId, timestamp ?? DateTime.now().millisecondsSinceEpoch, f,
      nonce, normalizeAddress(from));
}

UnsignedTx _tokenTx(_Base b, TokenFields f) => b.build(
    c.TxType.token,
    f,
    tokenPayload(
        op: f.op.code,
        tokenId: f.tokenId,
        symbol: f.symbol,
        name: f.name,
        decimals: f.decimals,
        cap: f.cap,
        amount: f.amount,
        recipient: f.recipient));

String _units(Object v, String what) {
  final s = v is BigInt || v is int ? v.toString() : v.toString().trim();
  if (!_unitsRe.hasMatch(s)) {
    throw ArgumentError(
        '$what must be a non-negative integer of base units, got $v');
  }
  return s;
}

String _checkKey(String key) {
  if (!_keyRe.hasMatch(key)) {
    throw ArgumentError(
        'validatorKey must be a compressed secp256k1 public key (66 hex chars)');
  }
  return key.toLowerCase();
}

String _checkTokenId(String id) {
  if (!_tokenIdRe.hasMatch(id)) {
    throw ArgumentError('tokenId must be a 64-hex transaction hash');
  }
  return id.toLowerCase();
}
