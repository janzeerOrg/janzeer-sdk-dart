#!/usr/bin/env bash
# Run every example against the network in JANZEER_NODE_URL (see sdk_conformance/e2e/node-up.sh).
set -uo pipefail
[ -n "${JANZEER_NODE_URL:-}" ] || { echo "JANZEER_NODE_URL is not set"; exit 1; }
cd "$(dirname "$0")/.."
fail=0
for f in example/*.dart; do echo; echo "=== $f"; dart run "$f" || fail=1; done
exit $fail
