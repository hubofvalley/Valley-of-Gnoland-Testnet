#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/resources/valleyofGnoland.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"

fail() { echo "RUNTIME_PAYLOAD_CONTRACT_FAIL: $*" >&2; exit 1; }

runtime_ref=$(sed -n 's/^readonly VALLEY_RUNTIME_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$MAIN")
[ "$runtime_ref" = "d932d2033c84126950fce6c2785e391edf11d005" ] || fail "unexpected reviewed runtime payload ref: ${runtime_ref:-missing}"

grep -Fq 'safe_stop_preflight' "$UPDATER" || fail "updater safe-stop guard missing"
grep -Fq 'Fetched Gno source does not match the pinned Pearl commit.' "$UPDATER" || fail "updater fetch pin verification missing"
grep -Fq 'Choose a snapshot provider:' "$SNAPSHOT" || fail "snapshot provider menu missing"
grep -Fq 'safe_stop_preflight || return 1' "$SNAPSHOT" || fail "snapshot safe-stop guard missing"

echo "RUNTIME_PAYLOAD_CONTRACT_OK"
