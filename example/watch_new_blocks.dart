import 'dart:io';
import 'package:janzeer_sdk/janzeer_sdk.dart';

/// Watches new blocks over WebSocket.
/// Usage: JANZEER_WS_URL=wss://explorer.janzeer.org/rpc/ws dart example/watch_new_blocks.dart
Future<void> main() async {
  final wsUrl = Platform.environment['JANZEER_WS_URL'] ?? 'ws://localhost:7019/rpc/ws';
  final seconds = int.tryParse(Platform.environment['EXAMPLE_SECONDS'] ?? '30') ?? 30;

  print('Connecting to $wsUrl...');
  final ws = await JanzeerRpcWs.connect(wsUrl);

  print('Subscribing to new blocks...');
  final subscription = await ws.subscribeNewBlocks(
    NewBlocksParams(includeTransactions: false),
    (block) {
      print('New block: #${block.height} | Hash: ${block.hash} | Producer: ${block.producer} | Txs: ${block.transactionCount}');
    },
  );

  await Future.delayed(Duration(seconds: seconds));

  print('Closing subscription and connection...');
  await subscription.cancel();
  await ws.close();
}
