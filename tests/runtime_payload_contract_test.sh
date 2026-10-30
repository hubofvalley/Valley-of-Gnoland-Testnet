#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/resources/valleyofGnoland.sh"
INSTALLER="$ROOT/resources/gnoland_node_install_testnet.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"

fail() { echo "RUNTIME_PAYLOAD_CONTRACT_FAIL: $*" >&2; exit 1; }

runtime_ref=$(sed -n 's/^readonly VALLEY_RUNTIME_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$MAIN")
[ "$runtime_ref" = "616aae9235dc41d71c001cda0c64589eb42bd1b7" ] || fail "unexpected reviewed runtime payload ref: ${runtime_ref:-missing}"

grep -Fq 'safe_stop_preflight' "$UPDATER" || fail "updater safe-stop guard missing"
grep -Fq 'BINARY_RELEASE_TAG="v1.7.0-rc.1"' "$UPDATER" || fail "v1.7 binary tag missing from pinned updater"
grep -Fq 'post_start_health_check' "$UPDATER" || fail "post-start health gate missing from pinned updater"
grep -Fq 'build_binaries_from_release_source' "$INSTALLER" || fail "binary-release source build missing from pinned installer"
if grep -Fq 'Onyx install/update blocked: pinned v1.5.0 is obsolete' "$MAIN"; then
    fail "stale v1.5 launcher blocker remains"
fi
download_line=$(grep -nF '"${VALLEY_RUNTIME_BASE_URL}/${relative_path}" -o "$script_file"' "$MAIN" | cut -d: -f1)
[ -n "$download_line" ] || fail "pinned helper download path missing"
grep -Fq 'Fetched Gno source does not match the pinned Onyx commit.' "$UPDATER" || fail "updater fetch pin verification missing"
grep -Fq 'Choose a snapshot provider:' "$SNAPSHOT" || fail "snapshot provider menu missing"
grep -Fq 'safe_stop_preflight || return 1' "$SNAPSHOT" || fail "snapshot safe-stop guard missing"

echo "RUNTIME_PAYLOAD_CONTRACT_OK"
