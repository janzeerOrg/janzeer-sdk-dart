# Vault — a secret at rest

`package:janzeer_sdk/vault.dart` seals a mnemonic (or any string) under a password so a wallet can persist it in
secure storage, a file or a keychain entry.

```dart
import 'dart:convert';
import 'package:janzeer_sdk/vault.dart';

final blob = encryptVault(mnemonic, password);          // VaultBlob {v: 1, salt, iv, ct} — base64 fields
await storage.write('janzeer.vault', jsonEncode(blob.toJson()));

try {
  final phrase = decryptVault(VaultBlob.fromJson(jsonDecode(stored)), password);
} on VaultException {
  // wrong password or tampered blob
}
```

The map-shaped `Vault.encrypt(secret, password)` / `Vault.decrypt(map, password)` API and the `compute()` entry
points `vaultEncryptIsolate` / `vaultDecryptIsolate` are kept for the Janzeer wallet; `Isolate.run` versions live
in `package:janzeer_sdk/isolate.dart` (see [flutter](flutter.md)).

## Format (v1)

| Field | Value |
|---|---|
| key | PBKDF2-HMAC-SHA256, 250 000 rounds, 16-byte random `salt`, 32-byte key |
| cipher | AES-256-GCM, 12-byte random `iv`, `ct` = ciphertext ‖ 16-byte tag |
| encoding | all three fields base64 |

Blobs are interchangeable between this SDK, the Dart SDK and the Kotlin SDK (the conformance kit's
`vault-fixture.json` pins it) and with the wallets that used the older browser-side implementation.

## Notes

- Pure JavaScript (`@noble/ciphers`, `@noble/hashes`): works on plain-http pages where `crypto.subtle` is
  unavailable, and in Node without flags.
- 250 000 PBKDF2 rounds take ~100–300 ms on a laptop and more on a phone; run `decryptVault` off the UI isolate
  (`decryptVaultInBackground`) if that matters to you.
- A vault protects a phrase at rest; it does not make a weak password strong. Pair it with the platform's
  biometric/keychain unlock where available.
