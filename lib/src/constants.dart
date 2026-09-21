/// Chain constants — every value mirrors the node (`Constants.kt` / `application.yaml consensus.*`) and is
/// pinned by the conformance vectors or the e2e flow.
library;

/// `consensus.network-id`, bound into every signed transaction preimage (cross-network replay protection).
const String networkId = 'janzeer';

/// Native coin decimals: amounts are scaled ×10^8 into an int64 on the wire.
const int decimals = 8;

/// Display ticker of the native coin.
const String ticker = 'JNZ';

/// Minimum fee of every transaction, in JNZ.
const String minFee = '0.01';

/// Minimum transfer amount unless the transfer carries a memo.
const String minTransfer = '0.1';

/// Maximum memo (`data`) length in UTF-8 bytes.
const int maxMemoBytes = 256;

/// Exact fee of a validator registration.
const String validatorFee = '3';

/// Exact, NON-REFUNDABLE deposit of a validator registration.
const String validatorDeposit = '2000';

/// Exact fee of a token CREATE; other token ops pay [minFee].
const String tokenCreateFee = '5';

/// The node / API / wire-protocol versions this SDK release was built and tested against.
class SpecVersion {
  SpecVersion._();

  /// `GET info/version` → `version`
  static const String node = '0.1.0';

  /// REST envelope `version` and JSON-RPC `apiVersion`
  static const String api = '1.1.0';

  /// peer-to-peer wire protocol (informational)
  static const String protocol = '3.2.0';

  /// conformance vectors format consumed by this SDK's tests
  static const int vectors = 2;
}

/// JZT-1 token operation codes carried in the `op` byte.
enum TokenOp {
  /// create a token (the tokenId is the tx hash)
  create(0),

  /// mint units to a recipient (issuer only)
  mint(1),

  /// burn the sender's units (issuer only)
  burn(2),

  /// change the cap (issuer only)
  setCap(3),

  /// move units to a recipient
  transfer(4);

  const TokenOp(this.code);

  /// the wire byte
  final int code;

  /// name as the node reports it (`CREATE`, `SETCAP`, …)
  String get wireName => switch (this) {
        TokenOp.create => 'CREATE',
        TokenOp.mint => 'MINT',
        TokenOp.burn => 'BURN',
        TokenOp.setCap => 'SETCAP',
        TokenOp.transfer => 'TRANSFER',
      };

  /// From the wire byte.
  static TokenOp fromCode(int code) => values.firstWhere((o) => o.code == code,
      orElse: () => throw RangeError('unknown token op $code'));

  /// From the node's name.
  static TokenOp? fromWireName(String? name) => name == null
      ? null
      : values
          .cast<TokenOp?>()
          .firstWhere((o) => o!.wireName == name, orElse: () => null);
}

/// Client-submittable transaction types (the RPC `txView.type` strings).
enum TxType {
  /// native-coin transfer
  transfer('transfer', 'transactions/transfers', 'janzeer_sendTransfer'),

  /// JZT-1 token operation
  token('token', 'transactions/tokens', 'janzeer_sendToken'),

  /// validator registration (fee 3, deposit 2000)
  registerValidator('registerValidator', 'transactions/validators',
      'janzeer_sendRegisterValidator'),

  /// validator exit
  exitValidator('exitValidator', 'transactions/exit-validators',
      'janzeer_sendExitValidator');

  const TxType(this.wireName, this.restPath, this.rpcMethod);

  /// the RPC `type` string
  final String wireName;

  /// REST path relative to the API base
  final String restPath;

  /// the `janzeer_send*` method
  final String rpcMethod;
}

/// Server-side limits (informational; the node enforces them).
class Limits {
  Limits._();

  /// max `size` of a paged list
  static const int pageSize = 100;

  /// max `toHeight - fromHeight` of `janzeer_getBlocks`
  static const int blockRange = 100;

  /// max `timeoutMs` of one `janzeer_waitForFinality` call
  static const int waitForFinalityMs = 60000;

  /// subscriptions per WebSocket session
  static const int subscriptionsPerSession = 16;

  /// addresses per `addressActivity` subscription
  static const int watchedAddresses = 1000;

  /// requests per `/rpc` batch
  static const int rpcBatch = 50;
}
