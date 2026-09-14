# Migrating from `janzeer_crypto.dart` / `vault.dart` / `node_api.dart`

Before this SDK the Janzeer Flutter wallet carried its own `lib/core/crypto/janzeer_crypto.dart`,
`vault.dart` and an untyped Dio client `node_api.dart`. Every function of the first two is available unchanged:

```diff
- import 'package:wallet/core/crypto/janzeer_crypto.dart';
- import 'package:wallet/core/crypto/vault.dart';
+ import 'package:janzeer_sdk/crypto.dart';
+ import 'package:janzeer_sdk/vault.dart';
```

Same names, same results (the conformance test proves both APIs against the same vectors): `toScaledLong`,
`publicKeyToAddress`, `toChecksumAddress`, `isChecksumValid`, `generateMnemonic`, `validateMnemonic`,
`mnemonicToSeed`, `accountFromSeed`, `accountFromMnemonic`, `accountFromPrivateKey`, `transactionBytes`,
`transferPayload`, `promoterPayload`, `exitPromoterPayload`, `tokenPayload`, `hashBytes`, `signHash`,
`buildSignedTransfer`, `buildSignedPromoter`, `buildSignedExitPromoter`, `buildSignedTokenTx`, `TokenOp`,
`kNetworkId`, `bytesToHex`, `hexToBytes`, and the `compute()` entry points `deriveAccountIsolate`,
`buildSignedTransferIsolate`, `buildSignedPromoterIsolate`, `buildSignedExitPromoterIsolate`,
`buildSignedTokenTxIsolate`. `Vault.encrypt` / `Vault.decrypt`, `vaultEncryptIsolate` / `vaultDecryptIsolate`
are in `vault.dart`.

Two deliberate differences:

- The legacy `Account` class is now `LegacyAccount` (`privHex`, `pubHex`, `address`) because `Account` is the
  SDK's typed account. Code that only reads those three fields keeps compiling after a rename.
- `buildSignedPromoter` / `buildSignedExitPromoter` emit `validatorKey` (the node's request field) instead of
  `promoterKey` in the returned map, so the map can be POSTed as-is.

## Replacing `node_api.dart` with `JanzeerClient`

| Old (`NodeApi`) | New (`JanzeerClient`) |
|---|---|
| `getBalance(a)` → `String` | `balance(a)` → `String` (same: `'0'` for a fresh address) |
| `getNonce(a)` → `int` | `nonce(a)` → `int` |
| `getTransfers(a, size: 15)` → `Map` | `transfers.list(TxListQuery(address: a, size: 15))` → `Page<TransferTx>` |
| `getAddressTransfers(a, page:, size:, unconfirmed:)` | `transfers.list(TxListQuery(address: a, page: p, size: s, unconfirmed: u))` |
| `getPromoters()` (called `promoters`, a path that does not exist → always empty) | `validators.list()` — fixed by construction |
| `getInfo()` → `Map` | `explorerInfo()` → `ExplorerInfo` |
| `getBlocks(size:)` | `blocks.main.list(PageQuery(size: s))` |
| `getRecentTransfers()` / `getPendingTransfers()` | `transfers.list(TxListQuery(size: s))` / `…unconfirmed: true` |
| `postTransfer(body)` / `postPromoter` / `postExitPromoter` / `postToken` | `submit(signedTx)`, or `post('transactions/transfers', body)` for a hand-built map |
| `getTokenBalances(a)` / `getTokens()` / `getToken(id)` | `tokens.balancesOf(a)` / `tokens.list()` / `tokens.get(id)` |
| `Exception('…message…')` | typed exceptions (`NonceMismatchException`, `TxRejectedException`, `NetworkException`, …) whose `message` is the node's text |

Migrating a large screen layer in one go? `client.get(path)` returns the lossless tree; `toPlainNumbers(tree)`
turns it into exactly what `jsonDecode` gave you (`int` / `double`), so screens keep working while you move them to
the typed methods one by one.

Behavioural differences to know about:

- Typed results carry amounts as decimal strings and token quantities as `BigInt`; timestamps stay `int` ms.
- 404 on balance/nonce still means "fresh address"; `transfers.get` returns `null` instead of throwing.
- `TxBuilder` validates amounts, memo size and exact validator fees **locally** and throws `ArgumentError` before
  anything is sent.
- Timeouts are 15 s per request by default (`timeout:`), and a 429 is retried once.
