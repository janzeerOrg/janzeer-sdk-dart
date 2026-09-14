/// Unsigned / signed transaction objects.
library;

import 'dart:typed_data';

import '../amounts.dart';
import '../constants.dart' as c;
import '../hashes.dart';
import 'payloads.dart';

/// Type-specific fields of a transaction as they appear in the REST/RPC request body.
sealed class TxFields {
  const TxFields();

  /// The type-specific part of the JSON body.
  Map<String, Object?> toBody();
}

/// Native-coin transfer fields.
class TransferFields extends TxFields {
  /// decimal string
  final String amount;

  /// canonical recipient address
  final String recipientAddress;

  /// optional memo (≤ 256 UTF-8 bytes)
  final String? data;

  /// Construct.
  const TransferFields(
      {required this.amount, required this.recipientAddress, this.data});

  @override
  Map<String, Object?> toBody() => {
        'amount': amount,
        'recipientAddress': recipientAddress,
        if (data != null) 'data': data
      };
}

/// Validator registration fields.
class RegisterValidatorFields extends TxFields {
  /// exactly the deposit (`2000`)
  final String amount;

  /// the node's public key (hex)
  final String validatorKey;

  /// Construct.
  const RegisterValidatorFields(
      {required this.amount, required this.validatorKey});

  @override
  Map<String, Object?> toBody() =>
      {'amount': amount, 'validatorKey': validatorKey};
}

/// Validator exit fields.
class ExitValidatorFields extends TxFields {
  /// the node's public key (hex)
  final String validatorKey;

  /// Construct.
  const ExitValidatorFields({required this.validatorKey});

  @override
  Map<String, Object?> toBody() => {'validatorKey': validatorKey};
}

/// JZT-1 token operation fields. Amounts are integer base units as decimal strings.
class TokenFields extends TxFields {
  /// the operation
  final c.TokenOp op;

  /// target token (empty for CREATE)
  final String tokenId;

  /// CREATE only
  final String symbol;

  /// CREATE only
  final String name;

  /// CREATE only (display decimals)
  final int decimals;

  /// CREATE / SETCAP: max supply in base units
  final String? cap;

  /// CREATE (initial mint) / MINT / BURN / TRANSFER
  final String? amount;

  /// MINT / TRANSFER recipient
  final String? recipient;

  /// Construct.
  const TokenFields(
      {required this.op,
      this.tokenId = '',
      this.symbol = '',
      this.name = '',
      this.decimals = 0,
      this.cap,
      this.amount,
      this.recipient});

  @override
  Map<String, Object?> toBody() => {
        'op': op.code,
        if (tokenId.isNotEmpty) 'tokenId': tokenId,
        if (symbol.isNotEmpty) 'symbol': symbol,
        if (name.isNotEmpty) 'name': name,
        'decimals': decimals,
        if (cap != null) 'cap': cap,
        if (amount != null) 'amount': amount,
        if (recipient != null) 'recipient': recipient,
      };
}

/// A transaction that is fully specified but not yet signed. Produced by `TxBuilder`; sign it with
/// `account.signTx(tx)`, or sign [hash] elsewhere and attach it with [withSignature].
class UnsignedTx {
  /// the type
  final c.TxType type;

  /// network id bound into the preimage
  final String networkId;

  /// ms since epoch
  final int timestamp;

  /// decimal string
  final String fee;

  /// sender's next nonce
  final int nonce;

  /// canonical sender address
  final String senderAddress;

  /// type-specific fields
  final TxFields fields;

  /// the type-specific payload bytes
  final Uint8List payload;

  /// Construct (normally through `TxBuilder`).
  UnsignedTx({
    required this.type,
    String? networkId,
    required this.timestamp,
    required Object fee,
    required this.nonce,
    required this.senderAddress,
    required this.fields,
    required this.payload,
  })  : networkId = networkId ?? c.networkId,
        fee = normalizeAmount(fee);

  /// The exact bytes that are hashed and signed.
  Uint8List preimage() => transactionBytes(
      networkId: networkId,
      timestamp: timestamp,
      fee: fee,
      nonce: nonce,
      senderAddress: senderAddress,
      payload: payload);

  /// Double-SHA256 of the preimage, lowercase hex — the transaction id.
  String hash() => hashPreimage(preimage());

  /// Attach a signature (+ the signer's public key).
  SignedTx withSignature(String signature, String senderPublicKey) =>
      SignedTx(this, hash(), signature, senderPublicKey);
}

/// A signed transaction ready for `client.submit(tx)` / `rpc.send(tx)`.
class SignedTx {
  /// the unsigned transaction
  final UnsignedTx unsigned;

  /// transaction id (double-SHA256 of the preimage, hex)
  final String hash;

  /// Base64 DER ECDSA signature over [hash]
  final String signature;

  /// compressed secp256k1 public key, hex
  final String senderPublicKey;

  /// Construct (normally through `Account.signTx`).
  const SignedTx(
      this.unsigned, this.hash, this.signature, this.senderPublicKey);

  /// the type
  c.TxType get type => unsigned.type;

  /// REST path relative to the API base
  String get restPath => type.restPath;

  /// the `janzeer_send*` method
  String get rpcMethod => type.rpcMethod;

  /// type-specific fields
  TxFields get fields => unsigned.fields;

  /// The JSON body the node's REST endpoints and `janzeer_send*` methods accept. Amounts are strings.
  Map<String, Object?> toRestBody() => {
        'timestamp': unsigned.timestamp,
        'fee': unsigned.fee,
        'nonce': unsigned.nonce,
        'hash': hash,
        'senderAddress': unsigned.senderAddress,
        'senderPublicKey': senderPublicKey,
        'senderSignature': signature,
        ...unsigned.fields.toBody(),
      };

  /// Same as [toRestBody] (the RPC methods take the REST body as their single object parameter).
  Map<String, Object?> toRpcParams() => toRestBody();

  /// [toRestBody] plus `type`.
  Map<String, Object?> toJson() => {'type': type.wireName, ...toRestBody()};
}
