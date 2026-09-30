#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSIONS="$ROOT/VERSIONS.json"
README="$ROOT/README.md"
SNAPSHOT_DOC="$ROOT/docs/snapshots.md"
USAGE="$ROOT/docs/usage.md"
NODE_GUIDE="$ROOT/docs/node-guide.md"
MAIN="$ROOT/resources/valleyofGnoland.sh"

fail() { echo "SNAPSHOT_DOCS_CONTRACT_FAIL: $*" >&2; exit 1; }

[ "$(jq -r '.chain_id // empty' "$VERSIONS")" = "onyx-1" ] || fail "VERSIONS.json must identify onyx-1"
[ "$(jq -r '.snapshot.status // empty' "$VERSIONS")" = "unavailable" ] || fail "snapshot status must be unavailable"
[ "$(jq -r '.snapshot.script // empty' "$VERSIONS")" = "resources/apply_snapshot.sh" ] || fail "snapshot helper path missing"
[ "$(jq -r '.snapshot.providers.utsa.status // empty' "$VERSIONS")" = "unverified" ] || fail "UTSA provider status missing"
[ "$(jq -r '.snapshot.providers.hazen.status // empty' "$VERSIONS")" = "unavailable" ] || fail "Hazen provider status missing"

grep -Fq "Onyx snapshot support is currently unavailable" "$README" || fail "README does not explain Onyx snapshot availability"
grep -Fq "Onyx snapshot support is currently unavailable" "$SNAPSHOT_DOC" || fail "snapshot guide does not explain Onyx snapshot availability"
grep -Fq "UTSA" "$SNAPSHOT_DOC" || fail "snapshot guide does not retain UTSA option context"
grep -Fq "Hazen Network Solutions" "$SNAPSHOT_DOC" || fail "snapshot guide does not retain Hazen option context"
grep -Fq "catching_up=false" "$SNAPSHOT_DOC" || fail "snapshot guide does not state the safe-stop precondition"
grep -Fq "Onyx snapshot support is currently unavailable" "$USAGE" || fail "usage guide does not explain option 1c availability"
grep -Fq "Onyx snapshot support is currently unavailable" "$NODE_GUIDE" || fail "manual node guide does not explain snapshot availability"
grep -Fq "1c. Apply Snapshot" "$MAIN" || fail "interactive menu does not expose option 1c"

echo "SNAPSHOT_DOCS_CONTRACT_OK"
