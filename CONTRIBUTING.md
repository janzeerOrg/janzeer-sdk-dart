# Contributing

```bash
dart pub get
dart analyze --fatal-infos && dart format --set-exit-if-changed .
dart test                                   # unit + conformance vectors (no network); e2e is tag-excluded
dart doc                                    # doc/api
dart pub publish --dry-run
```

## End-to-end tests and examples

They need a running Janzeer network with the faucet-funded test wallet. With the private node repo checked out
next to the conformance kit:

```bash
../sdk_conformance/e2e/node-up.sh
eval "$(../sdk_conformance/e2e/node-up.sh --env)"
dart test --tags e2e test/e2e               # the 14-step SPEC flow
tool/run_examples.sh                        # every script in example/
../sdk_conformance/e2e/node-down.sh
```

Against any other network set `JANZEER_NODE_URL`, `JANZEER_RPC_URL`, `JANZEER_WS_URL`, `JANZEER_E2E_MNEMONIC`
(a funded wallet) and `JANZEER_E2E_RECIPIENT` yourself.

## Conformance vectors

`test/vectors/` is a vendored copy of `sdk_conformance/vectors/`. Never edit it by hand: after a node change run
`sdk_conformance/sync.sh --regen`; `vectors_test.dart` verifies the copy against `SHA256SUMS` on every run.

## Style

- Amounts are decimal strings at the API boundary; never `double` arithmetic on coin values.
- Every new node method gets a typed wrapper in `lib/src/rpc/methods.dart` or `lib/src/rest/client.dart`, a model,
  a unit test with a mocked transport, and a line in `CHANGELOG.md`.
- Public API says *validator*; *promoter* only survives in `crypto.dart`.
