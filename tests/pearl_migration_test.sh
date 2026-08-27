#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install_testnet.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
VERSIONS="$ROOT/VERSIONS.json"

fail() { echo "PEARL_MIGRATION_TEST_FAIL: $*" >&2; exit 1; }

facts=(
  'pearl-1'
  'chain/pearl'
  'c4c72fdd288c757e8da0d93aae867fa479b1b15c'
  'c45fe60c8c8a1f859d9e4d5aad7ce4d100ff0eb78302e71318ba0de481a8dc91'
  '055b24001a31de7054649a049c9f9db5282965713814b84f7f864e8e6efa237d'
  'a69017c6e9ce9d77d3bd2f1e811731f6353e0deba5da4f620672d58e5fcec804'
  'g1m37xukfq6yl555k93fcyzns83qnmgyax9zm875@seed-1.pearl.testnets.gno.land:26656'
  'g1ngukqd3khekaqjf90k45cglzm0l25wwzl2fkn2@seed-2.pearl.testnets.gno.land:26656'
)
for fact in "${facts[@]}"; do
    grep -Fq "$fact" "$INSTALLER" || fail "installer missing pinned Pearl fact: $fact"
done

grep -Fq 'MIGRATE-TO-PEARL' "$INSTALLER" || fail "Pearl migration confirmation missing"
grep -Fq 'sapphire-node-secrets.tar.gz' "$INSTALLER" || fail "Sapphire source backup naming missing"
grep -Fq -- '--chainid $CHAIN_ID --genesis genesis.json --skip-genesis-sig-verification' "$INSTALLER" || fail "Pearl service startup contract missing"
grep -Fq 'VALOPER_GAS_WANTED=50000000' "$MAIN" || fail "Pearl valoper gas wanted drifted"

[ "$(jq -r '.chain_id' "$VERSIONS")" = 'pearl-1' ] || fail "VERSIONS chain_id is not pearl-1"
[ "$(jq -r '.migration.from' "$VERSIONS")" = 'Gno.land Sapphire' ] || fail "migration source is not Sapphire"
[ "$(jq -r '.migration.to' "$VERSIONS")" = 'Gno.land Pearl' ] || fail "migration target is not Pearl"
[ "$(jq -r '.migration.state_reuse' "$VERSIONS")" = 'false' ] || fail "state reuse must be false"

active_runtime=("$INSTALLER" "$MAIN" "$UPDATER" "$SNAPSHOT" "$DOCTOR")
if grep -En 'MIGRATE-TO-SAPPHIRE|rpc\.sapphire\.testnets\.gno\.land|chain/sapphire/(gnoland|gnokey|genesis)' "${active_runtime[@]}"; then
    fail "active Sapphire runtime endpoint or old migration token remains"
fi

echo "PEARL_MIGRATION_TEST_OK"
