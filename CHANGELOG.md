# Changelog

All notable changes to `janzeer_sdk` are documented here ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
[SemVer](https://semver.org/)).

## 0.1.8 — 2026-11-11

No API change. `SpecVersion.node` is **0.1.13** (node hardening release after a full review: a peer is counted only under the key it proved in the handshake, a next-slot vote no longer discards the current slot, one reward transaction per block, format checks at intake, rate limit on `/rpc/ws`; API 1.1.0 / protocol 3.4.0 unchanged, rolling upgrade).

## 0.1.7 — 2026-11-11

Reliability fixes from a code review. Node pin unchanged (**0.1.12**, API 1.1.0 / protocol 3.4.0). No API change.

- **REST timeout covers the whole request.** The timeout wrapped only the body read; connect and headers ran outside it, so a host that accepted the connection and never answered hung every REST call (and the Flutter wallet with it). One deadline now covers the exchange.
- **`waitForFinality` / `sendAndWait` over REST survives a dropped poll.** One transport error while polling (the transaction was already accepted) used to surface as a network error — which a caller can mistake for a failed send and resend. The REST branch now retries until the deadline, like the JSON-RPC branch.
- **WebSocket, one reconnect chain.** Every failed open scheduled its own endless retry: `JanzeerRpcWs.connect()` to a node that was down threw, yet the object the caller never received kept reconnecting, and each `call()` during an outage added another chain. There is now a single pending attempt, and a failed `connect()` closes the client.
- **WebSocket, resume after a reconnect.** A `newBlocks` stream now resumes right after the last block it delivered. It used to re-send the original `fromHeight`, so the node replayed every block again (thousands of duplicates on a long-lived stream), and a stream without `fromHeight` silently skipped the blocks committed during the outage. Blocks are delivered exactly once by height.
- **WebSocket, a failed resubscribe is retried.** A subscription whose re-creation failed (the socket dropped again, a call timed out) was removed for good with an `WsError` event as the only trace. It now stays registered and is re-created on the next attempt.
- **WebSocket, no lost first notification.** A notification that arrives before its subscription id is registered is held and delivered once the subscribe call returns.

## 0.1.6 — 2026-11-09

No API change. `SpecVersion.node` is **0.1.12** (node critical fix F-058: GraalVM native nodes could not sync across a block carrying a token transaction, fixed in 0.1.12 with a build-time guard; API 1.1.0 / protocol 3.4.0 unchanged).

## 0.1.5 — 2026-11-01

No API change. `SpecVersion.node` is **0.1.11** (node maintenance release: the `jz` command-line client ships in the node bundle;
`GET /info/version` now returns `version`, `apiVersion` and `protocolVersion` like `/info`; API 1.1.0 / protocol 3.4.0 unchanged).

## 0.1.4 — 2026-10-31

No API change; dependency and correctness release.

- **The `bip39` package is gone.** The SDK now carries its own BIP39 word encoding (`lib/src/bip39.dart`, English wordlist copied from the
  reference `english.txt`, SHA-256 checksum) and is tested against the 24 reference vectors of trezor/python-mnemonic
  (`test/mnemonic_test.dart`). `Mnemonic.generate / validate / fromEntropy / toEntropy` behave exactly as before. Only the word encoding is
  BIP39; the seed stays Janzeer's own (`Mnemonic.toSeed`).
- Consequence: `pointycastle` now resolves to **4.0.0** (the dropped package pinned 3.x), and the transitive `hex` and `crypto` runtime
  dependencies disappear.
- Fix inherited from the replaced package: its random entropy drew each byte with `nextInt(255)`, so the byte value 0xff never occurred in a
  generated phrase (one bit of entropy lost per byte in theory). Generation now uses the full 0–255 range. Existing phrases are unaffected.

## 0.1.3 — 2026-10-28

pub.dev housekeeping, no code change.

- `pointycastle` constraint widened to `>=3.9.1 <5.0.0` (4.0.0 has no breaking change for the APIs this SDK uses; the resolved version is still
  decided by `bip39`, which pins 3.x).
- `example/README.md` indexes the five runnable programs (pub.dev's Example tab); shorter pubspec description.

## 0.1.2 — 2026-10-28

First release on pub.dev (`dart pub add janzeer_sdk`). Verified against node **0.1.10** (API 1.1.0 / protocol 3.4.0).

- `SpecVersion.protocol` now says **3.4.0**, the wire protocol the node has run since 0.1.0 (it was left at 3.2.0; informational only).

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
