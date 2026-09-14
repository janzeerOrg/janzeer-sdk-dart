/// High-level flows composed from the clients.
library;

import 'dart:async';

import 'constants.dart';
import 'errors.dart';
import 'rest/client.dart';
import 'rpc/methods.dart';
import 'rpc/types.dart';
import 'tx/types.dart';

/// Thrown by [waitForFinality] when the deadline passes; [last] is the most recent view (may be PENDING/UNKNOWN).
class FinalityTimeoutException extends JanzeerException {
  /// the tx
  final String hash;

  /// the last view
  final TxView? last;

  /// Construct.
  FinalityTimeoutException(this.hash, this.last)
      : super(
            'transaction $hash not final within the deadline (last status: ${last?.status.wireName ?? 'unknown'})');
}

/// Wait until [hash] is in a committed block. With an RPC transport ([RpcMethods]: HTTP or WS) it uses the node's
/// long-poll `janzeer_waitForFinality` in ≤ 60 s slices; with a [JanzeerClient] it polls the transaction endpoints.
/// Resolves with the FINAL [TxView]; throws [FinalityTimeoutException] on deadline.
Future<TxView> waitForFinality(Object source, String hash,
    {Duration timeout = const Duration(minutes: 3),
    Duration poll = const Duration(milliseconds: 1500)}) async {
  final deadline = DateTime.now().add(timeout);
  TxView? last;
  while (DateTime.now().isBefore(deadline)) {
    if (source is JanzeerClient) {
      last = await _restView(source, hash);
      if (last?.isFinal ?? false) return last!;
      await Future<void>.delayed(poll);
    } else if (source is RpcMethods) {
      final remaining = deadline.difference(DateTime.now()).inMilliseconds;
      final slice = remaining.clamp(1000, Limits.waitForFinalityMs);
      try {
        last = await source.waitForFinality(hash, timeoutMs: slice);
      } on RpcNotFoundException {
        last = null;
      } on NetworkException {
        await Future<void>.delayed(const Duration(seconds: 1));
        continue;
      }
      if (last?.isFinal ?? false) return last!;
    } else {
      throw ArgumentError('source must be a JanzeerClient or an RPC transport');
    }
  }
  throw FinalityTimeoutException(hash, last);
}

Future<TxView?> _restView(JanzeerClient client, String hash) async {
  final t = await client.transfers.get(hash) ??
      await client.tokenTxs.get(hash) ??
      await client.validatorTxs.get(hash) ??
      await client.exitValidatorTxs.get(hash);
  if (t == null) return null;
  return TxView(
      hash: t.hash,
      status: t.isFinal ? TxStatus.finalized : TxStatus.pending,
      timestamp: t.timestamp,
      fee: t.fee,
      senderAddress: t.senderAddress,
      senderPublicKey: t.senderPublicKey,
      senderSignature: t.senderSignature,
      blockHash: t.blockHash);
}

/// The sender's next nonce from either transport.
Future<int> nextNonce(Object source, String address) {
  if (source is JanzeerClient) return source.nonce(address);
  if (source is RpcMethods) return source.getNonce(address);
  throw ArgumentError('source must be a JanzeerClient or an RPC transport');
}

/// Submit a signed transaction and wait for finality. [via] is used for both unless [submitVia] is given.
Future<TxView> sendAndWait(Object via, SignedTx tx,
    {Object? submitVia, Duration timeout = const Duration(minutes: 3)}) async {
  final s = submitVia ?? via;
  if (s is JanzeerClient) {
    await s.submit(tx);
  } else if (s is RpcMethods) {
    await s.send(tx);
  } else {
    throw ArgumentError(
        'submitVia must be a JanzeerClient or an RPC transport');
  }
  return waitForFinality(via, tx.hash, timeout: timeout);
}
