// Watch an address over the WebSocket feed and stream new blocks (exits after EXAMPLE_SECONDS, default 40).
import 'dart:io';

import 'package:janzeer_sdk/janzeer_sdk.dart';

Future<void> main() async {
  final env = Platform.environment;
  final ws = await JanzeerRpcWs.connect(
      env['JANZEER_WS_URL'] ?? 'ws://localhost:7019/rpc/ws',
      onEvent: (e) => print('[ws] $e'));
  final watch = env['JANZEER_E2E_RECIPIENT'] ??
      '0x598b1301acef3baba6ce25e38dd17b723f7b98b1';

  final tip = await ws.getTip();
  await ws.subscribeNewBlocks(
      NewBlocksParams(fromHeight: (tip.height - 2).clamp(1, tip.height)),
      (b) => print(
          'block ${b.height} ${b.hash.substring(0, 12)} txs ${b.transactionsCount}'));
  await ws.subscribeAddressActivity(
      [watch],
      (ev) => print(
          'activity for $watch → ${ev.transaction.type} ${ev.transaction.hash.substring(0, 12)} ${ev.transaction.amount} in block ${ev.blockHeight}'));
  final seconds = int.tryParse(env['EXAMPLE_SECONDS'] ?? '') ?? 40;
  print('listening… (this example exits after $seconds s)');
  await Future<void>.delayed(Duration(seconds: seconds));
  await ws.close();
}
