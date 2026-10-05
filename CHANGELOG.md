# Changelog

All notable changes to `janzeer_sdk` are documented here ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
[SemVer](https://semver.org/)).

## Unreleased

- **Vault key derivation is about nine times faster** (PBKDF2-HMAC-SHA256, 250 000 rounds: 4.3 s → 0.5 s on a desktop, and from many seconds to about one on a phone). The SDK now carries its own implementation that compresses the two HMAC pad blocks once; output is byte-for-byte the same (`test/pbkdf2_test.dart` compares it with the generic derivator and the published vectors, on the VM and compiled to JavaScript), so existing vault blobs open unchanged. No API change.
- Verified against node **0.1.0** (P2P protocol 3.4.0): `SPEC_VERSION.node` bumped from 0.0.3. No API change for SDK users. New node rule worth knowing: a transaction's `timestamp` must be within 60 s ahead / 6 h behind the node's clock — sign right before you send.

## Versioning policy

- **MAJOR** — a change in the signed preimage, hashing, derivation or the REST envelope that makes older releases
  produce transactions a node rejects, or a breaking Dart API change.
- **MINOR** — new node methods, fields or SDK features; existing code keeps working.
- **PATCH** — fixes and documentation.

Each release states the node / API / protocol versions it was tested against (`SpecVersion`).

## 0.1.1 — 2026-09-14

### Added
- `NodeInfo` (REST `info()`) now carries `networkId`, `genesisHash`, `chainSpecDigest`, `version`, `apiVersion`, `protocolVersion`, `syncStatus` and `faucet` (node 0.0.3); older nodes are tolerated (defaults). Read `info().networkId` and pass it as `networkId:` to the builders to work on the public testnet (`janzeer-testnet`).

### Changed
- `SpecVersion`: node `0.0.3`, protocol `3.2.0`.

## 0.1.0 — 2026-09-14

First release.

- Keys: BIP39 mnemonics, Janzeer seed + `m/0/0/0` derivation, `Account` (mnemonic / private key / seed),
  canonical + EIP-55 addresses.
- Transactions: `TxBuilder` for transfer, validator registration/exit and all five JZT-1 token operations;
  `UnsignedTx` (preimage, hash) → `SignedTx` (REST body / RPC params). Local validation of amounts, memo size and
  exact validator fees.
- REST: `JanzeerClient` with typed models for every `/api/v1` endpoint, lossless number parsing, envelope
  unwrapping, 404 → empty/`null`, one automatic retry on 429.
- JSON-RPC: `JanzeerRpc` (HTTP, batches) and `JanzeerRpcWs` (WebSocket, auto-reconnect with re-subscription,
  `newBlocks` / `addressActivity` feeds), one typed method per `janzeer_*` method.
- Helpers: `waitForFinality` (server long-poll or REST polling), `sendAndWait`, `nextNonce`.
- Errors: `TxRejectedException` / `NonceMismatchException` shared by both transports, `RateLimitedException`,
  `NotSynchronizedException`, `RpcException` family.
- Vault: PBKDF2-SHA256/250k + AES-256-GCM, cross-SDK fixture; `Vault.encrypt/decrypt` map API kept.
- `isolate.dart`: `Isolate.run` helpers for derivation, vault and signing.
- Compat: `package:janzeer_sdk/crypto.dart` re-exports the `janzeer_crypto.dart` function API (incl. the
  `compute()` entry points); `toPlainNumbers` converts a lossless tree to `jsonDecode` shapes for migrating code.
- Tested against node 0.0.2 / API 1.1.0 / protocol 3.1.0 / vectors v2.
