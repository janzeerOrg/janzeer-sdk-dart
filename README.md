# janzeer_sdk

Official Dart SDK for the [Janzeer](https://janzeer.org) blockchain — a stake-free, permissionless Layer-1
with instant finality. Wallet keys and signing, transaction builders, a typed REST client, JSON-RPC over HTTP
and WebSocket subscriptions. Pure Dart (no Flutter dependency) with Flutter helpers; non-custodial by
construction: keys never leave your process, the node only verifies.

[![pub](https://img.shields.io/pub/v/janzeer_sdk)](https://pub.dev/packages/janzeer_sdk)
![license](https://img.shields.io/badge/license-Apache--2.0-blue)

```bash
dart pub add janzeer_sdk        # or: flutter pub add janzeer_sdk
```

## 60-second quickstart

```dart
import 'package:janzeer_sdk/janzeer_sdk.dart';

final client = JanzeerClient('http://localhost:7019');            // REST  (/api/v1)
final rpc    = JanzeerRpc('http://localhost:7019');               // JSON-RPC (/rpc)
final me     = Account.fromMnemonic('abandon abandon … about');   // 12/24-word BIP39 phrase

print('${me.checksumAddress} ${formatJnz(await client.balance(me.address))}');

final tx = me.signTx(TxBuilder.transfer(
  from: me.address, to: '0x598b1301acef3baba6ce25e38dd17b723f7b98b1',
  amount: '1.25', data: 'hello', nonce: await client.nonce(me.address),
));
await client.submit(tx);                                          // HTTP 201, or a typed exception
final fin = await waitForFinality(rpc, tx.hash);                  // one or two 15-second slots
print('final in block ${fin.blockHeight}');
```

That is the whole integration: derive → nonce → build → sign → submit → wait. A committed block is final
(2f+1 BFT commit), so there is no confirmation count.

## What is in the box

| Area | Entry points | Guide |
|---|---|---|
| Keys & addresses | `Mnemonic`, `Account`, `toChecksumAddress`, `isValidAddress` | [wallet-and-keys](doc/wallet-and-keys.md) |
| Transactions | `TxBuilder.transfer / registerValidator / exitValidator / token.*` → `UnsignedTx` → `SignedTx` | [sending-transactions](doc/sending-transactions.md) |
| Amounts | `toScaledLong`, `fromScaledLong`, `formatJnz`, `parseJnz`, `addAmounts`… | [sending-transactions](doc/sending-transactions.md#amounts) |
| REST | `JanzeerClient`: balances, nonces, transactions, blocks, validators, tokens (typed, paged) | [reading-chain-data](doc/reading-chain-data.md) |
| JSON-RPC | `JanzeerRpc` (HTTP, batches) and `JanzeerRpcWs` (WebSocket + `newBlocks` / `addressActivity`) | [json-rpc-and-subscriptions](doc/json-rpc-and-subscriptions.md) |
| Flows | `waitForFinality`, `sendAndWait`, `nextNonce` | [json-rpc-and-subscriptions](doc/json-rpc-and-subscriptions.md#finality) |
| Errors | `TxRejectedException`, `NonceMismatchException`, `RateLimitedException`, `RpcException`… | [errors](doc/errors.md) |
| Vault | `package:janzeer_sdk/vault.dart`: `encryptVault` / `decryptVault` (PBKDF2 + AES-GCM) | [vault](doc/vault.md) |
| Flutter | `package:janzeer_sdk/isolate.dart`: the heavy operations off the UI isolate | [flutter](doc/flutter.md) |
| Legacy API | `package:janzeer_sdk/crypto.dart`: the old `janzeer_crypto.dart` functions | [migration](doc/migration.md) |

Libraries: `janzeer_sdk.dart` (everything), `vault.dart`, `isolate.dart` (VM/Flutter only), `crypto.dart`.

## Platforms

Dart VM, Flutter (Android, iOS, desktop) and Flutter web / Dart web (`isolate.dart` is VM-only; the plain
synchronous calls work everywhere). Networking through `package:http` and `package:web_socket_channel`. All
cryptography is pure Dart (`pointycastle`).

## Compatibility

| SDK | Node | REST envelope `version` | Wire protocol | Vectors |
|---|---|---|---|---|
| 0.1.x | 0.0.2 | 1.1.0 | 3.1.0 | v2 |

`SpecVersion` carries these values; the e2e test checks them against the node on the first call.

## Examples

`example/`: [quickstart transfer](example/quickstart_transfer.dart), address-activity subscription, token
create + transfer, validator registration (dry run), vault round trip. `tool/run_examples.sh` runs them against
the network in `JANZEER_NODE_URL`.

## Conformance

Every release reproduces the shared [conformance vectors](doc/conformance.md) byte-for-byte and passes the
14-step end-to-end flow against a real network. `dart test` runs the vectors; `dart test --tags e2e` the flow.

## Documentation

Guides in `doc/` (start with [wallet-and-keys](doc/wallet-and-keys.md)) · API reference on pub.dev or
`dart doc` · chain documentation (developer guide, API reference, yellow paper): https://janzeer.org

## License

Apache-2.0. See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.
