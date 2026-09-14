/// Typed `janzeer_*` methods shared by the HTTP and WebSocket transports.
library;

import '../constants.dart';
import '../json.dart';
import '../rest/models.dart';
import '../tx/types.dart';
import 'types.dart';

/// Paging parameters of the RPC lists (`size` 1–100, node default 20).
class PageParams {
  /// 0-based
  final int? page;

  /// 1–100
  final int? size;

  /// Construct.
  const PageParams({this.page, this.size});

  Map<String, Object?> _params([Map<String, Object?> extra = const {}]) => {
        ...extra,
        if (page != null) 'page': page,
        if (size != null) 'size': size
      };
}

/// Anything that can perform a JSON-RPC call.
abstract class RpcTransport {
  /// Raw call: [params] by name (map) or by position (list). Throws the mapped SDK error on a JSON-RPC error.
  Future<Object?> call(String method, [Object? params]);
}

/// Every `janzeer_*` method, typed.
abstract class RpcMethods implements RpcTransport {
  /// `janzeer_methods`
  Future<List<RpcMethodSpec>> methods() async =>
      asArray(await call('janzeer_methods'))
          .map(RpcMethodSpec.fromJson)
          .toList();

  /// `janzeer_getInfo`
  Future<NodeInfoView> getInfo() async =>
      NodeInfoView.fromJson(await call('janzeer_getInfo'));

  /// `janzeer_getChainSpec`
  Future<ChainSpecView> getChainSpec() async =>
      ChainSpecView.fromJson(await call('janzeer_getChainSpec'));

  /// `janzeer_getStats`
  Future<StatsView> getStats() async =>
      StatsView.fromJson(await call('janzeer_getStats'));

  /// `janzeer_getEpoch`
  Future<EpochView> getEpoch() async =>
      EpochView.fromJson(await call('janzeer_getEpoch'));

  /// `janzeer_getAccount`
  Future<AccountView> getAccount(String address) async => AccountView.fromJson(
      await call('janzeer_getAccount', {'address': address}));

  /// spendable balance as a decimal string
  Future<String> getBalance(String address) async =>
      asDecimal(await call('janzeer_getBalance', {'address': address}));

  /// next nonce (committed + pending)
  Future<int> getNonce(String address) async =>
      asInt(await call('janzeer_getNonce', {'address': address}));

  /// `janzeer_getTokenBalances`
  Future<RpcPage<TokenBalance>> getTokenBalances(String address,
          [PageParams p = const PageParams()]) async =>
      RpcPage.from(
          await call(
              'janzeer_getTokenBalances', p._params({'address': address})),
          TokenBalance.fromJson);

  /// `janzeer_getTransactionsByAddress`
  Future<AddressTransactions> getTransactionsByAddress(String address,
          [PageParams p = const PageParams()]) async =>
      AddressTransactions.fromJson(await call(
          'janzeer_getTransactionsByAddress', p._params({'address': address})));

  /// Submit a signed transaction through its type's `janzeer_send*` method.
  Future<SendResult> send(SignedTx tx) async =>
      SendResult.fromJson(await call(tx.rpcMethod, tx.toRpcParams()));

  /// `janzeer_sendTransfer` with a raw body
  Future<SendResult> sendTransfer(Map<String, Object?> body) async =>
      SendResult.fromJson(await call('janzeer_sendTransfer', body));

  /// `janzeer_sendToken` with a raw body
  Future<SendResult> sendToken(Map<String, Object?> body) async =>
      SendResult.fromJson(await call('janzeer_sendToken', body));

  /// `janzeer_sendRegisterValidator` with a raw body
  Future<SendResult> sendRegisterValidator(Map<String, Object?> body) async =>
      SendResult.fromJson(await call('janzeer_sendRegisterValidator', body));

  /// `janzeer_sendExitValidator` with a raw body
  Future<SendResult> sendExitValidator(Map<String, Object?> body) async =>
      SendResult.fromJson(await call('janzeer_sendExitValidator', body));

  /// `janzeer_sendRawTransaction`
  Future<SendResult> sendRawTransaction(
          TxType type, Map<String, Object?> tx) async =>
      SendResult.fromJson(await call(
          'janzeer_sendRawTransaction', {'type': type.wireName, 'tx': tx}));

  /// Unified view of any transaction; `status` is UNKNOWN when the node has never seen the hash.
  Future<TxView> getTransactionByHash(String hash) async => TxView.fromJson(
      await call('janzeer_getTransactionByHash', {'hash': hash}));

  /// Server-side wait (≤ 60 000 ms per call). Returns the FINAL view, or the current view with `timedOut`. Prefer the `waitForFinality` helper.
  Future<TxView> waitForFinality(String hash, {int timeoutMs = 30000}) async =>
      TxView.fromJson(await call(
          'janzeer_waitForFinality', {'hash': hash, 'timeoutMs': timeoutMs}));

  /// `janzeer_estimateFee` — kind: `transfer` | `token` | `tokenCreate` | `registerValidator` | `exitValidator`
  Future<FeeEstimate> estimateFee(String kind) async =>
      FeeEstimate.fromJson(await call('janzeer_estimateFee', {'kind': kind}));

  /// `janzeer_getTip`
  Future<BlockView> getTip() async =>
      BlockView.fromJson(await call('janzeer_getTip'));

  /// `janzeer_getBlockByNumber`
  Future<BlockView> getBlockByNumber(int height,
          {bool includeTransactions = false}) async =>
      BlockView.fromJson(await call('janzeer_getBlockByNumber',
          {'height': height, 'includeTransactions': includeTransactions}));

  /// `janzeer_getBlockByHash`
  Future<BlockView> getBlockByHash(String hash,
          {bool includeTransactions = false}) async =>
      BlockView.fromJson(await call('janzeer_getBlockByHash',
          {'hash': hash, 'includeTransactions': includeTransactions}));

  /// ascending, at most 100 blocks per call
  Future<List<BlockView>> getBlocks(int fromHeight, int toHeight,
          {bool includeTransactions = false}) async =>
      asArray(await call('janzeer_getBlocks', {
        'fromHeight': fromHeight,
        'toHeight': toHeight,
        'includeTransactions': includeTransactions
      }))
          .map(BlockView.fromJson)
          .toList();

  /// `janzeer_getToken`
  Future<Token> getToken(String tokenId) async =>
      Token.fromJson(await call('janzeer_getToken', {'tokenId': tokenId}));

  /// `janzeer_listTokens`
  Future<RpcPage<Token>> listTokens(
          [PageParams p = const PageParams()]) async =>
      RpcPage.from(
          await call('janzeer_listTokens', p._params()), Token.fromJson);

  /// `janzeer_getTokenHolders`
  Future<RpcPage<TokenBalance>> getTokenHolders(String tokenId,
          [PageParams p = const PageParams()]) async =>
      RpcPage.from(
          await call(
              'janzeer_getTokenHolders', p._params({'tokenId': tokenId})),
          TokenBalance.fromJson);

  /// `janzeer_listValidators`
  Future<RpcPage<ValidatorInfo>> listValidators(
          [PageParams p = const PageParams()]) async =>
      RpcPage.from(await call('janzeer_listValidators', p._params()),
          ValidatorInfo.fromJson);

  /// `janzeer_getActiveValidators`
  Future<List<ValidatorInfo>> getActiveValidators() async =>
      asArray(await call('janzeer_getActiveValidators'))
          .map(ValidatorInfo.fromJson)
          .toList();

  /// `janzeer_getValidator`
  Future<ValidatorInfo> getValidator(String key) async =>
      ValidatorInfo.fromJson(await call('janzeer_getValidator', {'key': key}));
}
