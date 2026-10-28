# janzeer_sdk examples

Five small programs, each a complete flow against a running node. Point them at a network with
`JANZEER_NODE_URL` (default `http://localhost:7019`); `sdk_conformance/e2e/node-up.sh` starts a local one with a
funded wallet, and `tool/run_examples.sh` runs all five.

| Program | What it shows |
|---|---|
| [`quickstart_transfer.dart`](quickstart_transfer.dart) | Open a wallet from a mnemonic, read balance and nonce, sign and submit a transfer, wait for finality. |
| [`subscribe_address_activity.dart`](subscribe_address_activity.dart) | WebSocket subscription: live blocks and the transactions that touch one address. |
| [`token_create_and_transfer.dart`](token_create_and_transfer.dart) | Create a JZT-1 token, then move units of it. |
| [`register_validator.dart`](register_validator.dart) | Build and send the validator registration transaction (2000 JNZ deposit). |
| [`vault_roundtrip.dart`](vault_roundtrip.dart) | Encrypt a secret into the portable vault format and open it again. |

The shortest possible program:

```dart
import 'package:janzeer_sdk/janzeer_sdk.dart';

Future<void> main() async {
  final client = JanzeerClient('http://localhost:7019');
  final account = Account.fromMnemonic(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
  print('${account.checksumAddress}: ${formatJnz(await client.balance(account.address))} JNZ');
  final tx = account.signTx(TxBuilder.transfer(
      from: account.address,
      to: '0x598b1301acef3baba6ce25e38dd17b723f7b98b1',
      amount: '1.25',
      nonce: await client.nonce(account.address)));
  await client.submit(tx);
  print('submitted ${tx.hash}');
  client.close();
}
```

Keys never leave the program: every transaction is signed locally and only the signed bytes reach the node.
