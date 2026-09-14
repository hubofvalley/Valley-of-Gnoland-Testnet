#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SNAPSHOT_SCRIPT="$ROOT_DIR/resources/apply_snapshot.sh"

fail() { echo "SNAPSHOT_FAIL_CLOSED_TEST_FAIL: $*" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" <<<"$1" || fail "missing expected text: $2"; }

[ -f "$SNAPSHOT_SCRIPT" ] || fail "snapshot script missing"

# Pearl snapshot support must remain fail-closed. Keep the checks explicit so a
# future provider cannot quietly reintroduce mutation behind the visible menu.
if grep -Eq '(^|[^[:alnum:]_])(curl|wget|lz4|tar|pkill|systemctl)([^[:alnum:]_]|$)|rm -rf|(^|[^[:alnum:]_])mv[[:space:]]|(^|[^[:alnum:]_])mkdir[[:space:]]' "$SNAPSHOT_SCRIPT"; then
    fail "disabled snapshot helper contains forbidden operation"
fi

grep -Fq 'GNOLAND_TESTNET_HOME' "$SNAPSHOT_SCRIPT" || fail "snapshot helper lost testnet home variable"
grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME' "$SNAPSHOT_SCRIPT" || fail "snapshot helper lost testnet service variable"
grep -Fq 'Snapshot application is disabled for Pearl.' "$SNAPSHOT_SCRIPT" || fail "fail-closed message missing"
grep -Fq 'No provider was executed' "$SNAPSHOT_SCRIPT" || fail "no-mutation evidence missing"

menu_output=$(HOME="$(mktemp -d)" bash -c 'source "$1"; show_menu' _ "$SNAPSHOT_SCRIPT")
assert_contains "$menu_output" 'Pearl snapshot support is disabled.'
assert_contains "$menu_output" '1. Disabled'
assert_contains "$menu_output" '2. Exit'

if HOME="$(mktemp -d)" GNOLAND_TESTNET_HOME="/tmp/gnoland-testnet-fixture" GNOLAND_TESTNET_SERVICE_NAME="gnoland-testnet" bash -c 'source "$1"; apply_snapshot' _ "$SNAPSHOT_SCRIPT" >/tmp/gnoland-snapshot-test.out 2>&1; then
    fail "disabled snapshot path unexpectedly succeeded"
fi
assert_contains "$(cat /tmp/gnoland-snapshot-test.out)" 'No provider was executed'
rm -f /tmp/gnoland-snapshot-test.out

jq -e '.snapshot.status == "disabled"' "$ROOT_DIR/VERSIONS.json" >/dev/null || fail "VERSIONS.json snapshot status is not disabled"

echo "SNAPSHOT_FAIL_CLOSED_TEST_OK"
