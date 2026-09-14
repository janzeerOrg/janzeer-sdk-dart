# Flutter

`janzeer_sdk` is a pure Dart package, so it works unchanged in Flutter apps on Android, iOS, desktop and web.
Two things matter on a phone: the CPU-heavy operations and where the phrase is stored.

## Heavy operations off the UI isolate

Mnemonic → key derivation (PBKDF2 × 2048 + secp256k1) takes ~50–200 ms and the vault's PBKDF2 × 250 000 up to
a second or two on a low-end device — enough to freeze a button. `package:janzeer_sdk/isolate.dart` wraps them in
`Isolate.run` (VM/Flutter only; import it from a non-web code path):

```dart
import 'package:janzeer_sdk/isolate.dart';

final account = await deriveAccountInBackground(phrase);         // Account
final blob    = await encryptVaultInBackground(phrase, password); // VaultBlob
final phrase2 = await decryptVaultInBackground(blob, password);
final sig     = await signInBackground(unsignedTx, account.privateKeyHex);
final signed  = unsignedTx.withSignature(sig, account.publicKeyHex);
```

Prefer `compute()`? The single-argument entry points from the legacy API still exist in
`package:janzeer_sdk/crypto.dart` (`deriveAccountIsolate`, `buildSignedTransferIsolate`, …) and in `vault.dart`
(`vaultEncryptIsolate`, `vaultDecryptIsolate`).

Signing itself (one secp256k1 multiplication) is fast enough to run inline; only derivation and the vault need
the isolate.

## Storing the phrase

Encrypt it with the [vault](vault.md) and keep the blob in the platform's secure storage
(`flutter_secure_storage`, `get_secure_storage`, Keychain / Keystore). Keep the decrypted phrase and private key
in memory only while the wallet is unlocked; the `Account` object holds the key — drop the reference on lock.

## Networking

`JanzeerClient` and `JanzeerRpc` use `package:http`; `JanzeerRpcWs` uses `package:web_socket_channel`. On
Android emulators the host machine is `http://10.0.2.2:7019`. Give the user a "node URL" setting and rebuild the
clients when it changes (they are cheap). Both HTTP clients expose `close()`.

## Web

Everything except `isolate.dart` compiles to JavaScript. PBKDF2 × 250 000 in pure Dart on the web is slow (a few
seconds); consider a lower-iteration app-specific unlock or a Web Worker-based flow if you target browsers.
