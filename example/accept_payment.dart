// Accept a payment: watch an address over WebSocket, match invoice memo and amount, confirm finality.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:janzeer_sdk/janzeer_sdk.dart';

Future<void> main() async {
  final env = Platform.environment;
  final wsUrl = env['JANZEER_WS_URL'] ?? 'ws://localhost:7019/rpc/ws';
  final nodeUrl = env['JANZEER_NODE_URL'] ?? 'http://localhost:7019';
  final recipient = env['JANZEER_E2E_RECIPIENT'] ??
      '0x598b1301acef3baba6ce25e38dd17b723f7b98b1';
  const invoiceAmount = '0.5';

  final rng = Random.secure();
  final refHex = List.generate(
      3, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  final reference = 'inv-$refHex';
  final timeoutSeconds = int.tryParse(env['EXAMPLE_SECONDS'] ?? '') ?? 90;

  print(
      'waiting for payment: $reference $invoiceAmount JNZ to $recipient (timeout ${timeoutSeconds}s)');

  final ws = await JanzeerRpcWs.connect(wsUrl);
  final completer = Completer<AddressActivityEvent>();

  final sub = await ws.subscribeAddressActivity([recipient], (ev) {
    final tx = ev.transaction;
    if (tx.type == 'transfer' &&
        (tx.recipientAddress ?? '').toLowerCase() == recipient.toLowerCase() &&
        tx.data == reference &&
        tx.amount != null &&
        compareAmounts(tx.amount!, invoiceAmount) >= 0) {
      if (!completer.isCompleted) {
        completer.complete(ev);
      }
    }
  });

  // Pay invoice from test wallet so the example runs unattended
  final payer = Account.fromMnemonic(env['JANZEER_E2E_MNEMONIC'] ??
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
  final client = JanzeerClient(nodeUrl);
  try {
    final info = await client.info();
    final nonce = await client.nonce(payer.address);
    final tx = payer.signTx(TxBuilder.transfer(
      from: payer.address,
      to: recipient,
      amount: invoiceAmount,
      data: reference,
      nonce: nonce,
      networkId: info.networkId,
    ));
    await client.submit(tx);
    print('invoice payment submitted: tx ${tx.hash}');
  } finally {
    client.close();
  }

  AddressActivityEvent ev;
  try {
    ev = await completer.future.timeout(Duration(seconds: timeoutSeconds));
  } on TimeoutException {
    stderr.writeln(
        'timeout: no matching payment received within $timeoutSeconds seconds');
    await sub.unsubscribe();
    await ws.close();
    exitCode = 1;
    return;
  }

  try {
    final fin = await waitForFinality(ws, ev.transaction.hash,
        timeout: Duration(seconds: timeoutSeconds));
    if (fin.isFinal) {
      print('paid: $reference $invoiceAmount JNZ in block ${fin.blockHeight}');
    } else {
      stderr.writeln(
          'payment transaction ${ev.transaction.hash} ended with non-final status: ${fin.status.wireName}');
      exitCode = 1;
    }
  } catch (e) {
    stderr.writeln('waitForFinality failed: $e');
    exitCode = 1;
  } finally {
    await sub.unsubscribe();
    await ws.close();
  }
}
