#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install_testnet.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"

fail() { echo "MULTI_INSTANCE_TEST_FAIL: $*" >&2; exit 1; }

# Keep the testnet-scoped names as the only supported instance-variable API.
# Build the rejected legacy names without embedding them in this test, so a
# stale reference cannot satisfy this regression guard accidentally.
legacy_service_name=$(printf 'GNOLAND_%s' 'SERVICE_NAME')
legacy_home_name=$(printf 'GNOLAND_%s' 'HOME')
new_service_name='GNOLAND_TESTNET_SERVICE_NAME'
new_home_name='GNOLAND_TESTNET_HOME'
source_files=(
    "$ROOT"/resources/*.sh
    "$ROOT"/resources/node-doctor/*.bash
    "$ROOT"/tests/*.sh
    "$ROOT"/tests/node-doctor/*.bash
    "$ROOT"/docs/*.md
    "$ROOT/README.md"
)
for source_file in "${source_files[@]}"; do
    if grep -Fq "$legacy_service_name" "$source_file" || grep -Fq "$legacy_home_name" "$source_file"; then
        fail "unsupported instance variable reference remains in ${source_file#$ROOT/}"
    fi
done

grep -Fq "$new_service_name" "$INSTALLER" || fail "installer does not cover the testnet service variable"
grep -Fq "$new_home_name" "$INSTALLER" || fail "installer does not cover the testnet home variable"
grep -Fq "$new_service_name" "$UPDATER" || fail "updater does not cover the testnet service variable"
grep -Fq "$new_service_name" "$ROOT/resources/gnoland_node_doctor.sh" || fail "doctor does not cover the testnet service variable"
grep -Fq "$new_home_name" "$ROOT/resources/gnoland_node_doctor.sh" || fail "doctor does not cover the testnet home variable"
grep -Fq "$new_home_name" "$ROOT/docs/node-guide.md" || fail "node guide does not document the testnet home variable"

grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME:-gnoland-testnet}' "$INSTALLER" || fail "installer default service semantics drifted"
grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME:-gnoland-testnet}' "$UPDATER" || fail "updater default service semantics drifted"
grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME:-gnoland-testnet}' "$ROOT/resources/apply_snapshot.sh" || fail "snapshot helper default service semantics drifted"

grep -Fq 'service_belongs_to_instance()' "$INSTALLER" || fail "installer service ownership guard missing"
grep -Fq 'belongs to another instance' "$INSTALLER" || fail "installer collision refusal missing"
grep -Fq 'path_is_under_home()' "$INSTALLER" || fail "installer path guard missing"
grep -Fq 'GNOLAND_RPC_PORT="${GNOLAND_PORT}657"' "$INSTALLER" || fail "custom RPC prefix missing"
grep -Fq 'GNOLAND_P2P_PORT="${GNOLAND_PORT}656"' "$INSTALLER" || fail "custom P2P prefix missing"
grep -Fq 'GNOLAND_ABCI_PORT="${GNOLAND_PORT}658"' "$INSTALLER" || fail "custom ABCI prefix missing"
grep -Fq 'service_belongs_to_current_instance()' "$MAIN" || fail "main menu service ownership guard missing"
grep -Fq 'this service is not configured for pearl-1' "$UPDATER" || fail "updater Pearl gate missing"
grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME=${INPUT_SVC:-gnoland-testnet}' "$MAIN" || fail "menu default service semantics drifted"
grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME:-gnoland-testnet}' "$ROOT/resources/node-doctor/part-01.bash" || fail "modular Node Doctor default service semantics drifted"
grep -Fq 'GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME:-$(profile_value GNOLAND_TESTNET_SERVICE_NAME "gnoland-testnet")}' "$ROOT/resources/gnoland_node_doctor.sh" || fail "Node Doctor default service semantics drifted"
if grep -Fq "sed -i '/GNOLAND_/d" "$INSTALLER" "$MAIN"; then
    fail "testnet profile cleanup still deletes every GNOLAND_* export"
fi
for cleanup_file in "$INSTALLER" "$MAIN"; do
    grep -Fq '^export GNOLAND_TESTNET_HOME=/d' "$cleanup_file" || fail "testnet cleanup does not explicitly remove GNOLAND_TESTNET_HOME in ${cleanup_file#$ROOT/}"
    grep -Fq '^export GNOLAND_TESTNET_SERVICE_NAME=/d' "$cleanup_file" || fail "testnet cleanup does not explicitly remove GNOLAND_TESTNET_SERVICE_NAME in ${cleanup_file#$ROOT/}"
    if grep -Fq 'GNOLAND_MAINNET_HOME' "$cleanup_file" || grep -Fq 'GNOLAND_MAINNET_SERVICE_NAME' "$cleanup_file"; then
        fail "testnet cleanup may delete mainnet-scoped exports in ${cleanup_file#$ROOT/}"
    fi
done

if grep -REn '/usr/local/bin/(gnoland|gnokey)' "$ROOT/resources"; then
    fail "runtime scripts must not manage global Gnoland command links"
fi

echo "MULTI_INSTANCE_TEST_OK"
