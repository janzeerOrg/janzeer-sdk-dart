/// Signed-bytes (preimage) layouts — byte-for-byte `Transaction.bytes()` of the node.
library;

import 'dart:typed_data';

import '../amounts.dart';
import '../bytes.dart';
import '../constants.dart' as c;

/// `networkId ‖ timestamp(8) ‖ toScaledLong(fee)(8) ‖ nonce(8) ‖ senderAddress ‖ payload`.
Uint8List transactionBytes({
  String networkId = c.networkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required Uint8List payload,
}) =>
    concatBytes([
      utf8ToBytes(networkId),
      i64be(BigInt.from(timestamp)),
      i64be(toScaledLong(fee)),
      i64be(BigInt.from(nonce)),
      utf8ToBytes(senderAddress),
      payload,
    ]);

/// Transfer payload: `toScaledLong(amount)(8) ‖ recipientAddress ‖ (data ?? "")`.
Uint8List transferPayload(
        {required Object amount,
        required String recipientAddress,
        String? data}) =>
    concatBytes([
      i64be(toScaledLong(amount)),
      utf8ToBytes(recipientAddress),
      utf8ToBytes(data ?? '')
    ]);

/// Validator registration payload: `toScaledLong(amount)(8) ‖ validatorKey`.
Uint8List registerValidatorPayload(
        {required Object amount, required String validatorKey}) =>
    concatBytes([i64be(toScaledLong(amount)), utf8ToBytes(validatorKey)]);

/// Validator exit payload: `validatorKey` only (the deposit is non-refundable, so no amount).
Uint8List exitValidatorPayload({required String validatorKey}) =>
    utf8ToBytes(validatorKey);

/// Token payload: `op(1) ‖ LP(tokenId) ‖ LP(symbol) ‖ LP(name) ‖ int32(decimals) ‖ LP(cap) ‖ LP(amount) ‖ LP(recipient)`.
/// Token amounts are integer base units as decimal strings; absent fields are empty strings.
Uint8List tokenPayload({
  required int op,
  String? tokenId,
  String? symbol,
  String? name,
  int? decimals,
  String? cap,
  String? amount,
  String? recipient,
}) =>
    concatBytes([
      Uint8List.fromList([op & 0xff]),
      lenPrefixed(tokenId),
      lenPrefixed(symbol),
      lenPrefixed(name),
      ser32(decimals ?? 0),
      lenPrefixed(cap),
      lenPrefixed(amount),
      lenPrefixed(recipient),
    ]);
