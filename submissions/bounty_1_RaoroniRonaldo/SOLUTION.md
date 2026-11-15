This is the complete deliverable for the Janzeer SDK Dart bounty. As a Senior Software Engineer and Web3 Researcher, I have implemented the missing RPC wrappers, added the necessary data models, included unit tests with mocked transports, and updated the documentation and changelog according to the requirements.

### Technical Summary
1.  **Models**: Added `ValidatorView`, `BlockView`, `TokenView`, `TokenBalanceView`, `TokenHolderView`, and `GenesisView` to `lib/src/rpc/types.dart`.
2.  **RPC Methods**: Implemented 8 new methods in `JanzeerRpc` (and by extension `JanzeerRpcWs`) within `lib/src/rpc/methods.dart`, handling pagination via `RpcPage<T>`.
3.  **Tests**: Created `test/rpc_methods_test.dart` using a mock transport to verify method names, parameter encoding, and response decoding.
4.  **Documentation**: Updated `doc/json-rpc-and-subscriptions.md` to reflect the new available methods.
5.  **Changelog**: Added a new entry for version `0.1.10`.

---

===FILE: lib/src/rpc/types.dart===
/// Typed JSON-RPC views (the `janzeer_*` result shapes).
library;

import '../constants.dart';
import '../json.dart';
import '../rest/models.dart';

/// Transaction status.
enum TxStatus {
  /// in a committed block
  finalized('FINAL'),

  /// in the mempool
  pending('PENDING'),

  /// never seen
  unknown('UNKNOWN');

  const TxStatus(this.wireName);

  /// the RPC string
  final String wireName;

  /// From the RPC string.
  static TxStatus from(String? s) =>
      values.firstWhere((x) => x.wireName == s, orElse: () => TxStatus.unknown);
}

/// Pagination parameters.
class PageParams {
  final int page;
  final int size;

  const PageParams({this.page = 1, this.size = 20});

  Map<String, dynamic> toJson() => {'page': page, 'size': size};
}

/// A paged result wrapper.
class RpcPage<T> {
  final List<T> items;
  final int total;
  final int page;
  final int size;
  final int pages;

  const RpcPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory RpcPage.fromJson(Map<String, dynamic> json, T Function(dynamic) itemFactory) {
    return RpcPage(
      items: (json['items'] as List? ?? []).map(itemFactory).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      size: json['size'] as int? ?? 0,
      pages: json['pages'] as int? ?? 0,
    );
  }
}

/// One shape for every transaction type; [type] tells them apart, FINAL carries block + receipt.
class TxView {
  final String hash;
  final String? type;
  final TxStatus status;
  final int? timestamp, nonce, blockHeight, decimals, slot;
  final String? fee,
      senderAddress,
      senderPublicKey,
      senderSignature,
      blockHash,
      amount,
      recipientAddress,
      data,
      validatorKey,
      tokenId,
      symbol,
      name,
      recipient,
      offenderKey;
  final TokenOp? op;
  final BigInt? cap, tokenAmount;
  final ReceiptView? receipt;
  final bool timedOut;

  const TxView({
    required this.hash,
    this.type,
    this.status = TxStatus.unknown,
    this.timestamp,
    this.nonce,
    this.blockHeight,
    this.decimals,
    this.slot,
    this.fee,
    this.senderAddress,
    this.senderPublicKey,
    this.senderSignature,
    this.blockHash,
    this.amount,
    this.recipientAddress,
    this.data,
    this.validatorKey,
    this.tokenId,
    this.symbol,
    this.name,
    this.recipient,
    this.offenderKey,
    this.op,
    this.cap,
    this.tokenAmount,
    this.receipt,
    this.timedOut = false,
  });

  factory TxView.fromJson(Map<String, dynamic> json) {
    return TxView(
      hash: json['hash'] as String? ?? '',
      type: json['type'] as String?,
      status: TxStatus.from(json['status'] as String?),
      timestamp: json['timestamp'] as int?,
      nonce: json['nonce'] as int?,
      blockHeight: json['blockHeight'] as int?,
      decimals: json['decimals'] as int?,
      slot: json['slot'] as int?,
      fee: json['fee'] as String?,
      senderAddress: json['senderAddress'] as String?,
      senderPublicKey: json['senderPublicKey'] as String?,
      senderSignature: json['senderSignature'] as String?,
      blockHash: json['blockHash'] as String?,
      amount: json['amount'] as String?,
      recipientAddress: json['recipientAddress'] as String?,
      data: json['data'] as String?,
      validatorKey: json['validatorKey'] as String?,
      tokenId: json['tokenId'] as String?,
      symbol: json['symbol'] as String?,
      name: json['name'] as String?,
      recipient: json['recipient'] as String?,
      offenderKey: json['offenderKey'] as String?,
      op: json['op'] != null ? TokenOp.values.firstWhere((e) => e.name == json['op']) : null,
      cap: json['cap'] != null ? BigInt.tryParse(json['cap'].toString()) : null,
      tokenAmount: json['tokenAmount'] != null ? BigInt.tryParse(json['token