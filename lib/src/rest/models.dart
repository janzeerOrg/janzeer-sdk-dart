/// Typed REST models. Coin amounts are decimal strings; token amounts are [BigInt]; timestamps are ms ints.
/// Mappers take the lossless JSON tree so no precision is lost on the way in.
library;

import '../constants.dart';
import '../json.dart';

/// A page of results.
class Page<T> {
  /// total elements
  final int total;

  /// this page
  final List<T> list;

  /// 0-based page index
  final int page;

  /// requested size
  final int pageSize;

  /// number of pages
  final int totalPages;

  /// Construct.
  const Page(
      {required this.total,
      required this.list,
      required this.page,
      required this.pageSize,
      required this.totalPages});

  /// Empty page.
  const Page.empty()
      : this(total: 0, list: const [], page: 0, pageSize: 0, totalPages: 0);

  /// Map a paged payload.
  static Page<T> from<T>(Object? v, T Function(Object?) item) {
    if (v == null) return Page<T>.empty();
    final o = asObject(v, 'page');
    final raw = o['list'];
    final list = raw is List<Object?> ? raw.map(item).toList() : <T>[];
    return Page(
        total: o['total'] == null ? list.length : asInt(o['total']),
        list: list,
        page: asOptInt(o['page']) ?? 0,
        pageSize: asOptInt(o['pageSize']) ?? list.length,
        totalPages: asOptInt(o['totalPages']) ?? 0);
  }
}

/// Query of every paged endpoint. [page] is 0-based; [size] 1–100 (node default 10).
class PageQuery {
  /// 0-based
  final int? page;

  /// 1–100
  final int? size;

  /// sort fields
  final List<String>? sortBy;

  /// `ASC` | `DESC`
  final String? sortDirection;

  /// Construct.
  const PageQuery({this.page, this.size, this.sortBy, this.sortDirection});

  /// As query parameters.
  Map<String, Object?> toQuery() => {
        'page': page,
        'size': size,
        'sortBy': sortBy?.join(','),
        'sortDirection': sortDirection
      };
}

/// `GET info`
class NodeInfo {
  /// the node's public key
  final String nodeKey;

  /// host
  final String host;

  /// P2P port
  final int port;

  /// Construct.
  const NodeInfo(
      {required this.nodeKey, required this.host, required this.port});

  /// Map.
  factory NodeInfo.fromJson(Object? v) {
    final o = asObject(v);
    return NodeInfo(
        nodeKey: asString(o['nodeKey'], 'nodeKey'),
        host: asString(o['host']),
        port: asInt(o['port']));
  }
}

/// `GET info/version`
class NodeVersion {
  /// node version
  final String version;

  /// API version
  final String protocolVersion;

  /// Construct.
  const NodeVersion({required this.version, required this.protocolVersion});

  /// Map.
  factory NodeVersion.fromJson(Object? v) {
    final o = asObject(v);
    return NodeVersion(
        version: asString(o['version']),
        protocolVersion: asString(o['protocolVersion']));
  }
}

/// `GET explorer/info`
class ExplorerInfo {
  /// fields
  final int nodesCount,
      blocksCount,
      transactionsCount,
      blockProductionTime,
      currentEpochNumber,
      currentEpochDate,
      validatorsCount;

  /// decimals
  final String transactionsPerSecond, maxSupply, circulatingSupply;

  /// Construct.
  const ExplorerInfo({
    required this.nodesCount,
    required this.blocksCount,
    required this.transactionsCount,
    required this.blockProductionTime,
    required this.transactionsPerSecond,
    required this.currentEpochNumber,
    required this.currentEpochDate,
    required this.validatorsCount,
    required this.maxSupply,
    required this.circulatingSupply,
  });

  /// Map.
  factory ExplorerInfo.fromJson(Object? v) {
    final o = asObject(v);
    return ExplorerInfo(
      nodesCount: asInt(o['nodesCount']),
      blocksCount: asInt(o['blocksCount']),
      transactionsCount: asInt(o['transactionsCount']),
      blockProductionTime: asInt(o['blockProductionTime']),
      transactionsPerSecond: asDecimal(o['transactionsPerSecond']),
      currentEpochNumber: asInt(o['currentEpochNumber']),
      currentEpochDate: asInt(o['currentEpochDate']),
      validatorsCount: asInt(o['validatorsCount']),
      maxSupply: asDecimal(o['maxSupply']),
      circulatingSupply: asDecimal(o['circulatingSupply']),
    );
  }
}

/// Common block fields.
abstract class BaseBlock {
  /// fields
  final int timestamp, height;

  /// hashes / keys
  final String previousHash, hash, signature, publicKey;

  /// Construct.
  const BaseBlock(
      {required this.timestamp,
      required this.height,
      required this.previousHash,
      required this.hash,
      required this.signature,
      required this.publicKey});
}

/// A main (transaction) block.
class MainBlock extends BaseBlock {
  /// transaction merkle root
  final String merkleHash;

  /// number of transactions
  final int transactionsCount;

  /// epoch
  final int epochIndex;

  /// Construct.
  const MainBlock(
      {required super.timestamp,
      required super.height,
      required super.previousHash,
      required super.hash,
      required super.signature,
      required super.publicKey,
      required this.merkleHash,
      required this.transactionsCount,
      required this.epochIndex});

  /// Map.
  factory MainBlock.fromJson(Object? v) {
    final o = asObject(v);
    return MainBlock(
        timestamp: asInt(o['timestamp']),
        height: asInt(o['height']),
        previousHash: asString(o['previousHash']),
        hash: asString(o['hash']),
        signature: asString(o['signature']),
        publicKey: asString(o['publicKey']),
        merkleHash: asString(o['merkleHash']),
        transactionsCount: asInt(o['transactionsCount']),
        epochIndex: asInt(o['epochIndex']));
  }
}

/// An epoch genesis block.
class GenesisBlock extends BaseBlock {
  /// epoch
  final int epochIndex;

  /// active validators in the epoch
  final int validatorsCount;

  /// Construct.
  const GenesisBlock(
      {required super.timestamp,
      required super.height,
      required super.previousHash,
      required super.hash,
      required super.signature,
      required super.publicKey,
      required this.epochIndex,
      required this.validatorsCount});

  /// Map.
  factory GenesisBlock.fromJson(Object? v) {
    final o = asObject(v);
    return GenesisBlock(
        timestamp: asInt(o['timestamp']),
        height: asInt(o['height']),
        previousHash: asString(o['previousHash']),
        hash: asString(o['hash']),
        signature: asString(o['signature']),
        publicKey: asString(o['publicKey']),
        epochIndex: asInt(o['epochIndex']),
        validatorsCount: asInt(o['validatorsCount']));
  }
}

/// One line of an execution receipt.
class ReceiptResult {
  /// from / to
  final String from, to;

  /// decimal amount
  final String amount;

  /// memo / error
  final String? data, error;

  /// Construct.
  const ReceiptResult(
      {required this.from,
      required this.to,
      required this.amount,
      this.data,
      this.error});

  /// Map.
  factory ReceiptResult.fromJson(Object? v) {
    final o = asObject(v);
    return ReceiptResult(
        from: asString(o['from']),
        to: asString(o['to']),
        amount: asDecimal(o['amount']),
        data: asOptString(o['data']),
        error: asOptString(o['error']));
  }
}

/// `GET transactions/{hash}/receipt`
class Receipt {
  /// the tx
  final String transactionHash;

  /// lines
  final List<ReceiptResult> results;

  /// Construct.
  const Receipt({required this.transactionHash, required this.results});

  /// Map.
  factory Receipt.fromJson(Object? v) {
    final o = asObject(v);
    return Receipt(
        transactionHash: asString(o['transactionHash']),
        results: asArray(o['results']).map(ReceiptResult.fromJson).toList());
  }
}

/// Common transaction fields.
abstract class BaseTx {
  /// id
  final String hash;

  /// ms
  final int timestamp;

  /// decimal
  final String fee;

  /// sender
  final String senderAddress, senderSignature, senderPublicKey;

  /// `null` while pending
  final String? blockHash;

  /// Construct.
  const BaseTx(
      {required this.hash,
      required this.timestamp,
      required this.fee,
      required this.senderAddress,
      required this.senderSignature,
      required this.senderPublicKey,
      this.blockHash});

  /// true once in a committed block
  bool get isFinal => blockHash != null;
}

Map<String, Object?> _base(Object? v) => asObject(v, 'tx');

/// A native-coin transfer.
class TransferTx extends BaseTx {
  /// applied successfully (pending txs report true)
  final bool status;

  /// decimal
  final String amount;

  /// recipient / memo
  final String? recipientAddress, data;

  /// receipt lines when final
  final List<ReceiptResult>? results;

  /// Construct.
  const TransferTx(
      {required super.hash,
      required super.timestamp,
      required super.fee,
      required super.senderAddress,
      required super.senderSignature,
      required super.senderPublicKey,
      super.blockHash,
      required this.status,
      required this.amount,
      this.recipientAddress,
      this.data,
      this.results});

  /// Map.
  factory TransferTx.fromJson(Object? v) {
    final o = _base(v);
    final r = o['results'];
    return TransferTx(
        hash: asString(o['hash']),
        timestamp: asInt(o['timestamp']),
        fee: asDecimal(o['fee']),
        senderAddress: asString(o['senderAddress']),
        senderSignature: asString(o['senderSignature']),
        senderPublicKey: asString(o['senderPublicKey']),
        blockHash: asOptString(o['blockHash']),
        status: o['status'] == null ? true : asBool(o['status']),
        amount: asDecimal(o['amount']),
        recipientAddress: asOptString(o['recipientAddress']),
        data: asOptString(o['data']),
        results:
            r is List<Object?> ? r.map(ReceiptResult.fromJson).toList() : null);
  }
}

/// A validator registration (the node reports the key as `nodeKey`).
class RegisterValidatorTx extends BaseTx {
  /// node public key
  final String validatorKey;

  /// deposit
  final String amount;

  /// Construct.
  const RegisterValidatorTx(
      {required super.hash,
      required super.timestamp,
      required super.fee,
      required super.senderAddress,
      required super.senderSignature,
      required super.senderPublicKey,
      super.blockHash,
      required this.validatorKey,
      required this.amount});

  /// Map.
  factory RegisterValidatorTx.fromJson(Object? v) {
    final o = _base(v);
    return RegisterValidatorTx(
        hash: asString(o['hash']),
        timestamp: asInt(o['timestamp']),
        fee: asDecimal(o['fee']),
        senderAddress: asString(o['senderAddress']),
        senderSignature: asString(o['senderSignature']),
        senderPublicKey: asString(o['senderPublicKey']),
        blockHash: asOptString(o['blockHash']),
        validatorKey: asString(o['nodeKey'] ?? o['validatorKey'], 'nodeKey'),
        amount: asDecimal(o['amount']));
  }
}

/// A validator exit.
class ExitValidatorTx extends BaseTx {
  /// node public key
  final String validatorKey;

  /// Construct.
  const ExitValidatorTx(
      {required super.hash,
      required super.timestamp,
      required super.fee,
      required super.senderAddress,
      required super.senderSignature,
      required super.senderPublicKey,
      super.blockHash,
      required this.validatorKey});

  /// Map.
  factory ExitValidatorTx.fromJson(Object? v) {
    final o = _base(v);
    return ExitValidatorTx(
        hash: asString(o['hash']),
        timestamp: asInt(o['timestamp']),
        fee: asDecimal(o['fee']),
        senderAddress: asString(o['senderAddress']),
        senderSignature: asString(o['senderSignature']),
        senderPublicKey: asString(o['senderPublicKey']),
        blockHash: asOptString(o['blockHash']),
        validatorKey: asString(o['nodeKey'] ?? o['validatorKey'], 'nodeKey'));
  }
}

/// A block reward (system transaction).
class RewardTx extends BaseTx {
  /// decimal
  final String reward;

  /// validator wallet
  final String recipientAddress;

  /// Construct.
  const RewardTx(
      {required super.hash,
      required super.timestamp,
      required super.fee,
      required super.senderAddress,
      required super.senderSignature,
      required super.senderPublicKey,
      super.blockHash,
      required this.reward,
      required this.recipientAddress});

  /// Map.
  factory RewardTx.fromJson(Object? v) {
    final o = _base(v);
    return RewardTx(
        hash: asString(o['hash']),
        timestamp: asInt(o['timestamp']),
        fee: asDecimal(o['fee']),
        senderAddress: asString(o['senderAddress']),
        senderSignature: asString(o['senderSignature']),
        senderPublicKey: asString(o['senderPublicKey']),
        blockHash: asOptString(o['blockHash']),
        reward: asDecimal(o['reward']),
        recipientAddress: asString(o['recipientAddress']));
  }
}

/// A JZT-1 token transaction.
class TokenTx extends BaseTx {
  /// operation
  final TokenOp op;

  /// token id (for CREATE this is the tx hash)
  final String tokenId;

  /// CREATE fields
  final String symbol, name;

  /// display decimals
  final int decimals;

  /// base units
  final BigInt? cap, amount;

  /// recipient
  final String? recipient;

  /// Construct.
  const TokenTx(
      {required super.hash,
      required super.timestamp,
      required super.fee,
      required super.senderAddress,
      required super.senderSignature,
      required super.senderPublicKey,
      super.blockHash,
      required this.op,
      required this.tokenId,
      required this.symbol,
      required this.name,
      required this.decimals,
      this.cap,
      this.amount,
      this.recipient});

  /// Map.
  factory TokenTx.fromJson(Object? v) {
    final o = _base(v);
    return TokenTx(
        hash: asString(o['hash']),
        timestamp: asInt(o['timestamp']),
        fee: asDecimal(o['fee']),
        senderAddress: asString(o['senderAddress']),
        senderSignature: asString(o['senderSignature']),
        senderPublicKey: asString(o['senderPublicKey']),
        blockHash: asOptString(o['blockHash']),
        op: TokenOp.fromCode(asInt(o['op'])),
        tokenId: asString(o['tokenId']),
        symbol: asString(o['symbol']),
        name: asString(o['name']),
        decimals: asInt(o['decimals']),
        cap: asOptBigInt(o['cap']),
        amount: asOptBigInt(o['amount']),
        recipient: asOptString(o['recipient']));
  }
}

/// `GET validators`
class Validator {
  /// wallet address
  final String address;

  /// node public key
  final String nodeKey;

  /// Construct.
  const Validator({required this.address, required this.nodeKey});

  /// Map.
  factory Validator.fromJson(Object? v) {
    final o = asObject(v);
    return Validator(
        address: asString(o['address']), nodeKey: asString(o['nodeKey']));
  }
}

/// `GET validators/view`
class ValidatorView {
  /// wallet address
  final String address;

  /// node public key
  final String publicKey;

  /// registration time
  final int timestamp;

  /// Construct.
  const ValidatorView(
      {required this.address,
      required this.publicKey,
      required this.timestamp});

  /// Map.
  factory ValidatorView.fromJson(Object? v) {
    final o = asObject(v);
    return ValidatorView(
        address: asString(o['address']),
        publicKey: asString(o['publicKey']),
        timestamp: asInt(o['timestamp']));
  }
}

/// A token definition.
class Token {
  /// id
  final String tokenId;

  /// symbol / name / issuer
  final String symbol, name, issuer;

  /// display decimals
  final int decimals;

  /// base units
  final BigInt cap, totalSupply;

  /// Construct.
  const Token(
      {required this.tokenId,
      required this.symbol,
      required this.name,
      required this.decimals,
      required this.cap,
      required this.totalSupply,
      required this.issuer});

  /// Map.
  factory Token.fromJson(Object? v) {
    final o = asObject(v);
    return Token(
        tokenId: asString(o['tokenId']),
        symbol: asString(o['symbol']),
        name: asString(o['name']),
        decimals: asInt(o['decimals']),
        cap: asBigInt(o['cap']),
        totalSupply: asBigInt(o['totalSupply']),
        issuer: asString(o['issuer']));
  }
}

/// A token balance.
class TokenBalance {
  /// token
  final String tokenId;

  /// holder
  final String holder;

  /// base units
  final BigInt balance;

  /// Construct.
  const TokenBalance(
      {required this.tokenId, required this.holder, required this.balance});

  /// Map.
  factory TokenBalance.fromJson(Object? v) {
    final o = asObject(v);
    return TokenBalance(
        tokenId: asString(o['tokenId']),
        holder: asString(o['holder']),
        balance: asBigInt(o['balance']));
  }
}
