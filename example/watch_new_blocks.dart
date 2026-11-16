// Watch new blocks over the WebSocket feed (exits after EXAMPLE_SECONDS, default 40).
import 'dart:io';

import 'package:janzeer_sdk/janzeer_sdk.dart';

Future<void> main() async {
  final env = Platform.environment;
  final ws = await JanzeerRpcWs.connect(
    env['JANZEER_WS_URL'] ?? 'ws://localhost:7019/rpc/ws',
    onEvent: (e) => print('[ws] $e'),
  );

  final tip = await ws.getTip();
  final fromHeight = (tip.height - 2).clamp(1, tip.height);
  var seen = 0;
  final maxBlocks = int.tryParse(env['EXAMPLE_MAX_BLOCKS'] ?? '') ?? 5;

  await ws.subscribeNewBlocks(
    NewBlocksParams(fromHeight: fromHeight, includeTransactions: false),
    (b) {
      seen++;
      print(
        'block ${b.height} ${b.hash.substring(0, 12)} producer=${b.producer} txs=${b.transactionsCount}',
      );
      if (seen >= maxBlocks) {
        // allow the main flow to exit on the next timer tick
      }
    },
  );

  final seconds = int.tryParse(env['EXAMPLE_SECONDS'] ?? '') ?? 40;
  print('listening for new blocks… (exits after $seconds s or $maxBlocks blocks)');
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline) && seen < maxBlocks) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  await ws.close();
}
