#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/resources/apply_snapshot.sh"

fail() { echo "SNAPSHOT_TEST_FAIL: $*" >&2; exit 1; }

set +e
output=$(bash "$SCRIPT" 2>&1)
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "Pearl snapshot helper must fail closed with exit 2"
[[ "$output" == *"Sapphire-specific"* ]] || fail "source-chain safety explanation missing"
[[ "$output" == *"MUST NOT be applied to pearl-1"* ]] || fail "Pearl chain guard message missing"

if grep -Eq 'share118\.utsa\.tech|hazennetworksolutions\.com/gnoland-sapphire' "$SCRIPT"; then
    fail "Sapphire snapshot provider URL remains executable"
fi

echo "SNAPSHOT_TEST_OK"
