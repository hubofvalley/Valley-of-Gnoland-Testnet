#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/resources/valleyofGnoland.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"

fail() { echo "RUNTIME_PAYLOAD_CONTRACT_FAIL: $*" >&2; exit 1; }

runtime_ref=$(sed -n 's/^readonly VALLEY_RUNTIME_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$MAIN")
[ "$runtime_ref" = "3874fe043eedebd4c594a83cc5a91e7cd3851c31" ] || fail "unexpected reviewed runtime payload ref: ${runtime_ref:-missing}"

grep -Fq 'safe_stop_preflight' "$UPDATER" || fail "updater safe-stop guard missing"
grep -Fq 'resources/gnoland_node_install_testnet.sh|resources/gnoland_update.sh)' "$MAIN" || fail "obsolete Onyx helpers are not blocked"
grep -Fq 'Onyx install/update blocked: pinned v1.5.0' "$MAIN" || fail "missing obsolete Onyx helper error"
guard_line=$(grep -nF 'resources/gnoland_node_install_testnet.sh|resources/gnoland_update.sh)' "$MAIN" | cut -d: -f1)
download_line=$(grep -nF '"${VALLEY_RUNTIME_BASE_URL}/${relative_path}" -o "$script_file"' "$MAIN" | cut -d: -f1)
[ -n "$guard_line" ] && [ -n "$download_line" ] && [ "$guard_line" -lt "$download_line" ] || fail "obsolete Onyx guard must precede helper download"
grep -Fq 'Fetched Gno source does not match the pinned Onyx commit.' "$UPDATER" || fail "updater fetch pin verification missing"
grep -Fq 'Choose a snapshot provider:' "$SNAPSHOT" || fail "snapshot provider menu missing"
grep -Fq 'safe_stop_preflight || return 1' "$SNAPSHOT" || fail "snapshot safe-stop guard missing"

echo "RUNTIME_PAYLOAD_CONTRACT_OK"
