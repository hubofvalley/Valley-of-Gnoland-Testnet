#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install_testnet.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
VERSIONS="$ROOT/VERSIONS.json"

fail() { echo "ONYX_MIGRATION_TEST_FAIL: $*" >&2; exit 1; }

facts=(
  'onyx-1'
  'chain/onyx'
  '5cdbc25fcde0b7569911a4e308ae5d2f6e96c399'
  '4b006fd7ccdec052865accc84dd29b2b76f8b57b2560789a15eedaa88f0e26c5'
  '8dcff48228a881e398d238e3e14760c175c872fb164e85f21e5b4ee94a8b076d'
  '878eb6599161f491a37fdcbd4214477ad28d5d6208f8428f0bffcd3115cd35b4'
  'g1x5mlj5ava0dw9vkf4j6admjlzswm6f06p44krn@seed-1.onyx.testnets.gno.land:26656'
  'g1grq5zswt0dlwwe7clr4359w70k2ewgse0gcwck@seed-2.onyx.testnets.gno.land:26656'
)
for fact in "${facts[@]}"; do
    grep -Fq "$fact" "$INSTALLER" || fail "installer missing pinned Onyx fact: $fact"
done

grep -Fq 'MIGRATE-TO-ONYX' "$INSTALLER" || fail "Onyx migration confirmation missing"
grep -Fq 'pearl-node-secrets.tar.gz' "$INSTALLER" || fail "Pearl source backup naming missing"
grep -Fq -- '--data-dir $GNOLAND_TESTNET_HOME --chainid $CHAIN_ID --genesis $GENESIS_FILE --skip-genesis-sig-verification' "$INSTALLER" || fail "Onyx service startup/data-dir contract missing"
grep -Fq 'config init -config-path "$CONFIG_FILE" -force' "$INSTALLER" || fail "config init is not pinned to GNOLAND_TESTNET_HOME"
grep -Fq 'secrets init -data-dir "$SECRETS_DIR" -force' "$INSTALLER" || fail "secrets init is not pinned to GNOLAND_TESTNET_HOME"

grep -Fq 'VALOPER_GAS_WANTED=50000000' "$MAIN" || fail "Onyx valoper base gas wanted is not the reviewed 50M floor"
grep -Fq "suggested gas-wanted (gas used + 5%)" "$MAIN" || fail "Onyx valoper adaptive gas parser missing"
grep -Fq 'Retry the same registration with suggested gas-wanted' "$MAIN" || fail "Onyx valoper adaptive retry prompt missing"
grep -Fq -- '-gas-wanted "$suggested_gas"' "$MAIN" || fail "Onyx valoper retry does not use gnokey suggested gas"

[ "$(jq -r '.chain_id' "$VERSIONS")" = 'onyx-1' ] || fail "VERSIONS chain_id is not onyx-1"
[ "$(jq -r '.migration.from' "$VERSIONS")" = 'Gno.land Pearl' ] || fail "migration source is not Pearl"
[ "$(jq -r '.migration.to' "$VERSIONS")" = 'Gno.land Onyx' ] || fail "migration target is not Onyx"
[ "$(jq -r '.migration.state_reuse' "$VERSIONS")" = 'false' ] || fail "state reuse must be false"

active_runtime=("$INSTALLER" "$MAIN" "$UPDATER" "$SNAPSHOT" "$DOCTOR")
if grep -En 'MIGRATE-TO-PEARL|rpc\.pearl\.testnets\.gno\.land|chain/pearl/(gnoland|gnokey|genesis)' "${active_runtime[@]}"; then
    fail "active Pearl runtime endpoint or old migration token remains"
fi

echo "ONYX_MIGRATION_TEST_OK"