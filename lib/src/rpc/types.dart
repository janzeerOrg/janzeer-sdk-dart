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

/// One shape for every transaction type; [type] tells them apart, FINAL carries block + receipt.
class TxView {
  /// id
  final String hash;

  /// `transfer` | `token` | `registerValidator` | `exitValidator` | `reward` | `slashing`
  final String? type;

  /// status
  final TxStatus status;

  /// base fields (null for UNKNOWN)
  final int? timestamp, nonce, blockHeight, decimals, slot;

  /// strings
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

  /// token op name
  final TokenOp? op;

  /// token base units
  final BigInt? cap, tokenAmount;

  /// receipt when final
  final ReceiptView? receipt;

  /// set by `janzeer_waitForFinality` when the wait expired
  final bool timedOut;

  /// Construct.
  const TxView({
    required this.hash,
    this.type,
    required this.status,
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

  /// true when in a committed block
  bool get isFinal => status == TxStatus.finalized;

  /// Map.
  factory TxView.fromJson(Object? v) {
    final o = asObject(v, 'tx');
    final type = asOptString(o['type']);
    final isToken = type == 'token';
    final r = o['receipt'];
    return TxView(
      hash: asString(o['hash'], 'hash'),
      type: type,
      status: TxStatus.from(asOptString(o['status'])),
      timestamp: asOptInt(o['timestamp']),
      nonce: asOptInt(o['nonce']),
      blockHeight: asOptInt(o['blockHeight']),
      decimals: asOptInt(o['decimals']),
      slot: asOptInt(o['slot']),
      fee: asOptDecimal(o['fee']),
      senderAddress: asOptString(o['senderAddress']),
      senderPublicKey: asOptString(o['senderPublicKey']),
      senderSignature: asOptString(o['senderSignature']),
      blockHash: asOptString(o['blockHash']),
      amount: isToken ? null : asOptDecimal(o['amount']),
      recipientAddress: asOptString(o['recipientAddress']),
      data: asOptString(o['data']),
      validatorKey: asOptString(o['validatorKey']),
      tokenId: asOptString(o['tokenId']),
      symbol: asOptString(o['symbol']),
      name: asOptString(o['name']),
      recipient: asOptString(o['recipient']),
      offenderKey: asOptString(o['offenderKey']),
      op: TokenOp.fromWireName(asOptString(o['op'])),
      cap: asOptBigInt(o['cap']),
      tokenAmount: isToken ? asOptBigInt(o['amount']) : null,
      receipt: r is Map<String, Object?> ? ReceiptView.fromJson(r) : null,
      timedOut: o['timedOut'] == true,
    );
  }
}

/// Receipt inside a [TxView].
class ReceiptView {
  /// applied successfully
  final bool successful;

  /// lines
  final List<ReceiptResult> results;

  /// Construct.
  const ReceiptView({required this.successful, required this.results});

  /// Map.
  factory ReceiptView.fromJson(Object? v) {
    final o = asObject(v, 'receipt');
    return ReceiptView(
        successful: asBool(o['successful']),
        results: asArray(o['results']).map(ReceiptResult.fromJson).toList());
  }
}

/// A block as the RPC reports it.
class BlockView {
  /// `main` | `genesis`
  final String type;

  /// ints
  final int height, timestamp, transactionsCount;

  /// strings
  final String hash, previousHash, producer, signature;

  /// optional
  final int? epochIndex, activeAnchorCount;

  /// merkle roots (main)
  final String? transactionMerkleHash, stateMerkleHash, receiptMerkleHash;

  /// epoch validators (genesis)
  final List<String>? validators;

  /// present when requested with `includeTransactions`
  final List<TxView>? transactions;

  /// Construct.
  const BlockView(
      {required this.type,
      required this.height,
      required this.timestamp,
      required this.transactionsCount,
      required this.hash,
      required this.previousHash,
      required this.producer,
      required this.signature,
      this.epochIndex,
      this.activeAnchorCount,
      this.transactionMerkleHash,
      this.stateMerkleHash,
      this.receiptMerkleHash,
      this.validators,
      this.transactions});

  /// Map.
  factory BlockView.fromJson(Object? v) {
    final o = asObject(v, 'block');
    final vs = o['validators'];
    final txs = o['transactions'];
    return BlockView(
      type: asString(o['type']),
      height: asInt(o['height']),
      timestamp: asInt(o['timestamp']),
      transactionsCount: asOptInt(o['transactionsCount']) ?? 0,
      hash: asString(o['hash']),
      previousHash: asString(o['previousHash']),
      producer: asString(o['producer']),
      signature: asString(o['signature']),
      epochIndex: asOptInt(o['epochIndex']),
      activeAnchorCount: asOptInt(o['activeAnchorCount']),
      transactionMerkleHash: asOptString(o['transactionMerkleHash']),
      stateMerkleHash: asOptString(o['stateMerkleHash']),
      receiptMerkleHash: asOptString(o['receiptMerkleHash']),
      validators:
          vs is List<Object?> ? vs.map((x) => asString(x)).toList() : null,
      transactions:
          txs is List<Object?> ? txs.map(TxView.fromJson).toList() : null,
    );
  }
}

/// `janzeer_getAccount`
class AccountView {
  /// address
  final String address;

  /// spendable (committed − pending debits) / committed
  final String balance, committedBalance;

  /// the nonce to sign the next transaction with / committed / pending count
  final int nextNonce, committedNonce, pendingCount;

  /// registered a validator
  final bool isValidatorWallet;

  /// Construct.
  const AccountView(
      {required this.address,
      required this.balance,
      required this.committedBalance,
      required this.nextNonce,
      required this.committedNonce,
      required this.pendingCount,
      required this.isValidatorWallet});

  /// Map.
  factory AccountView.fromJson(Object? v) {
    final o = asObject(v, 'account');
    return AccountView(
        address: asString(o['address']),
        balance: asDecimal(o['balance']),
        committedBalance: asDecimal(o['committedBalance']),
        nextNonce: asInt(o['nextNonce']),
        committedNonce: asInt(o['committedNonce']),
        pendingCount: asInt(o['pendingCount']),
        isValidatorWallet: asBool(o['isValidatorWallet']));
  }
}

/// `janzeer_getInfo`
class NodeInfoView {
  /// strings
  final String chainId,
      chainSpecDigest,
      version,
      apiVersion,
      wireProtocolVersion,
      nodeKey,
      syncStatus,
      finality;

  /// tip
  final ({int height, String hash, int timestamp}) tip;

  /// ints
  final int epoch, peers;

  /// flags
  final bool synchronized, chainCorrupt;

  /// Construct.
  const NodeInfoView(
      {required this.chainId,
      required this.chainSpecDigest,
      required this.version,
      required this.apiVersion,
      required this.wireProtocolVersion,
      required this.nodeKey,
      required this.tip,
      required this.epoch,
      required this.syncStatus,
      required this.synchronized,
      required this.chainCorrupt,
      required this.peers,
      required this.finality});

  /// Map.
  factory NodeInfoView.fromJson(Object? v) {
    final o = asObject(v, 'info');
    final t = asObject(o['tip'], 'tip');
    return NodeInfoView(
        chainId: asString(o['chainId']),
        chainSpecDigest: asString(o['chainSpecDigest']),
        version: asString(o['version']),
        apiVersion: asString(o['apiVersion']),
        wireProtocolVersion: asString(o['wireProtocolVersion']),
        nodeKey: asString(o['nodeKey']),
        tip: (
          height: asInt(t['height']),
          hash: asString(t['hash']),
          timestamp: asInt(t['timestamp'])
        ),
        epoch: asInt(o['epoch']),
        syncStatus: asString(o['syncStatus']),
        synchronized: asBool(o['synchronized']),
        chainCorrupt: asBool(o['chainCorrupt']),
        peers: asInt(o['peers']),
        finality: asString(o['finality']));
  }
}

/// `janzeer_getChainSpec`
class ChainSpecView {
  /// strings
  final String networkId,
      digest,
      rewardBlock,
      rewardTailFloor,
      minimumFee,
      validatorRegistrationFee,
      validatorDeposit,
      tokenCreateFee,
      maxSupply,
      treasuryAddress;

  /// ints
  final int epochHeight,
      timeSlotDurationMs,
      timeSlotIntervalMs,
      slotPeriodMs,
      validatorsCount,
      rotatingProducerSeats,
      blockCapacity,
      rewardHalvingPeriod,
      treasuryFeeShareBps,
      tokenActivationHeight,
      amountScale;

  /// Construct.
  const ChainSpecView(
      {required this.networkId,
      required this.digest,
      required this.rewardBlock,
      required this.rewardTailFloor,
      required this.minimumFee,
      required this.validatorRegistrationFee,
      required this.validatorDeposit,
      required this.tokenCreateFee,
      required this.maxSupply,
      required this.treasuryAddress,
      required this.epochHeight,
      required this.timeSlotDurationMs,
      required this.timeSlotIntervalMs,
      required this.slotPeriodMs,
      required this.validatorsCount,
      required this.rotatingProducerSeats,
      required this.blockCapacity,
      required this.rewardHalvingPeriod,
      required this.treasuryFeeShareBps,
      required this.tokenActivationHeight,
      required this.amountScale});

  /// Map.
  factory ChainSpecView.fromJson(Object? v) {
    final o = asObject(v, 'chainSpec');
    return ChainSpecView(
        networkId: asString(o['networkId']),
        digest: asString(o['digest']),
        rewardBlock: asDecimal(o['rewardBlock']),
        rewardTailFloor: asDecimal(o['rewardTailFloor']),
        minimumFee: asDecimal(o['minimumFee']),
        validatorRegistrationFee: asDecimal(o['validatorRegistrationFee']),
        validatorDeposit: asDecimal(o['validatorDeposit']),
        tokenCreateFee: asDecimal(o['tokenCreateFee']),
        maxSupply: asDecimal(o['maxSupply']),
        treasuryAddress: asString(o['treasuryAddress']),
        epochHeight: asInt(o['epochHeight']),
        timeSlotDurationMs: asInt(o['timeSlotDurationMs']),
        timeSlotIntervalMs: asInt(o['timeSlotIntervalMs']),
        slotPeriodMs: asInt(o['slotPeriodMs']),
        validatorsCount: asInt(o['validatorsCount']),
        rotatingProducerSeats: asInt(o['rotatingProducerSeats']),
        blockCapacity: asInt(o['blockCapacity']),
        rewardHalvingPeriod: asInt(o['rewardHalvingPeriod']),
        treasuryFeeShareBps: asInt(o['treasuryFeeShareBps']),
        tokenActivationHeight: asInt(o['tokenActivationHeight']),
        amountScale: asInt(o['amountScale']));
  }
}

/// `janzeer_getStats`
class StatsView {
  /// ints
  final int nodesCount,
      blocksCount,
      transactionsCount,
      pendingTransactions,
      blockProductionTimeMs,
      epoch,
      epochStart,
      validatorsCount;

  /// decimals
  final String transactionsPerSecond, maxSupply, circulatingSupply;

  /// Construct.
  const StatsView(
      {required this.nodesCount,
      required this.blocksCount,
      required this.transactionsCount,
      required this.pendingTransactions,
      required this.blockProductionTimeMs,
      required this.epoch,
      required this.epochStart,
      required this.validatorsCount,
      required this.transactionsPerSecond,
      required this.maxSupply,
      required this.circulatingSupply});

  /// Map.
  factory StatsView.fromJson(Object? v) {
    final o = asObject(v, 'stats');
    return StatsView(
        nodesCount: asInt(o['nodesCount']),
        blocksCount: asInt(o['blocksCount']),
        transactionsCount: asInt(o['transactionsCount']),
        pendingTransactions: asInt(o['pendingTransactions']),
        blockProductionTimeMs: asInt(o['blockProductionTimeMs']),
        epoch: asInt(o['epoch']),
        epochStart: asInt(o['epochStart']),
        validatorsCount: asInt(o['validatorsCount']),
        transactionsPerSecond: asDecimal(o['transactionsPerSecond']),
        maxSupply: asDecimal(o['maxSupply']),
        circulatingSupply: asDecimal(o['circulatingSupply']));
  }
}

/// `janzeer_getEpoch`
class EpochView {
  /// ints
  final int index,
      genesisHeight,
      startTimestamp,
      epochHeight,
      nextGenesisHeight,
      slotPeriodMs,
      currentSlot,
      activeAnchorCount;

  /// genesis hash
  final String genesisHash;

  /// current slot owner (null between epochs)
  final String? currentSlotOwner;

  /// validator keys
  final List<String> validators;

  /// Construct.
  const EpochView(
      {required this.index,
      required this.genesisHeight,
      required this.startTimestamp,
      required this.epochHeight,
      required this.nextGenesisHeight,
      required this.slotPeriodMs,
      required this.currentSlot,
      required this.activeAnchorCount,
      required this.genesisHash,
      this.currentSlotOwner,
      required this.validators});

  /// Map.
  factory EpochView.fromJson(Object? v) {
    final o = asObject(v, 'epoch');
    return EpochView(
        index: asInt(o['index']),
        genesisHeight: asInt(o['genesisHeight']),
        startTimestamp: asInt(o['startTimestamp']),
        epochHeight: asInt(o['epochHeight']),
        nextGenesisHeight: asInt(o['nextGenesisHeight']),
        slotPeriodMs: asInt(o['slotPeriodMs']),
        currentSlot: asInt(o['currentSlot']),
        activeAnchorCount: asInt(o['activeAnchorCount']),
        genesisHash: asString(o['genesisHash']),
        currentSlotOwner: asOptString(o['currentSlotOwner']),
        validators: asArray(o['validators']).map((x) => asString(x)).toList());
  }
}

/// `janzeer_listValidators` / `getValidator`
class ValidatorInfo {
  /// node public key
  final String key;

  /// wallet
  final String? walletAddress;

  /// registration time
  final int? registeredAt;

  /// flags (null when state is missing)
  final bool? active, banned, exited;

  /// Construct.
  const ValidatorInfo(
      {required this.key,
      this.walletAddress,
      this.registeredAt,
      this.active,
      this.banned,
      this.exited});

  /// Map.
  factory ValidatorInfo.fromJson(Object? v) {
    final o = asObject(v, 'validator');
    return ValidatorInfo(
        key: asString(o['key']),
        walletAddress: asOptString(o['walletAddress']),
        registeredAt: asOptInt(o['registeredAt']),
        active: o['active'] as bool?,
        banned: o['banned'] as bool?,
        exited: o['exited'] as bool?);
  }
}

/// `janzeer_estimateFee`
class FeeEstimate {
  /// kind
  final String kind;

  /// decimal
  final String fee;

  /// `minimum` | `exact`
  final String rule;

  /// always false (no fee market)
  final bool feeMarket;

  /// Construct.
  const FeeEstimate(
      {required this.kind,
      required this.fee,
      required this.rule,
      required this.feeMarket});

  /// Map.
  factory FeeEstimate.fromJson(Object? v) {
    final o = asObject(v, 'fee');
    return FeeEstimate(
        kind: asString(o['kind']),
        fee: asDecimal(o['fee']),
        rule: asString(o['rule']),
        feeMarket: asBool(o['feeMarket']));
  }
}

/// `janzeer_send*`
class SendResult {
  /// the tx hash
  final String hash;

  /// always `PENDING`
  final String status;

  /// Construct.
  const SendResult({required this.hash, this.status = 'PENDING'});

  /// Map.
  factory SendResult.fromJson(Object? v) =>
      SendResult(hash: asString(asObject(v, 'send')['hash']));
}

/// A paged RPC result.
class RpcPage<T> {
  /// counts
  final int total, page, pageSize, totalPages;

  /// items
  final List<T> list;

  /// Construct.
  const RpcPage(
      {required this.total,
      required this.page,
      required this.pageSize,
      required this.totalPages,
      required this.list});

  /// Map.
  static RpcPage<T> from<T>(Object? v, T Function(Object?) item) {
    final o = asObject(v, 'page');
    return RpcPage(
        total: asInt(o['total']),
        page: asInt(o['page']),
        pageSize: asInt(o['pageSize']),
        totalPages: asInt(o['totalPages']),
        list: asArray(o['list']).map(item).toList());
  }
}

/// `janzeer_getTransactionsByAddress`
class AddressTransactions extends RpcPage<TxView> {
  /// mempool entries
  final List<TxView> pending;

  /// Construct.
  const AddressTransactions(
      {required super.total,
      required super.page,
      required super.pageSize,
      required super.totalPages,
      required super.list,
      required this.pending});

  /// Map.
  factory AddressTransactions.fromJson(Object? v) {
    final p = RpcPage.from(v, TxView.fromJson);
    final pend = asObject(v)['pending'];
    return AddressTransactions(
        total: p.total,
        page: p.page,
        pageSize: p.pageSize,
        totalPages: p.totalPages,
        list: p.list,
        pending: pend is List<Object?>
            ? pend.map(TxView.fromJson).toList()
            : const []);
  }
}

/// `janzeer_methods`
class RpcMethodSpec {
  /// name
  final String name;

  /// positional parameter names
  final List<String> params;

  /// description
  final String description;

  /// Construct.
  const RpcMethodSpec(
      {required this.name, required this.params, required this.description});

  /// Map.
  factory RpcMethodSpec.fromJson(Object? v) {
    final o = asObject(v);
    return RpcMethodSpec(
        name: asString(o['name']),
        params: asArray(o['params']).map((x) => asString(x)).toList(),
        description: asString(o['description']));
  }
}
