#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSIONS="$ROOT/VERSIONS.json"
README="$ROOT/README.md"
SNAPSHOT_DOC="$ROOT/docs/snapshots.md"
MAIN="$ROOT/resources/valleyofGnoland.sh"

fail() {
    echo "SNAPSHOT_DOCS_CONTRACT_FAIL: $*" >&2
    exit 1
}

[ "$(jq -r '.chain_id // empty' "$VERSIONS")" = "pearl-1" ] || fail "VERSIONS.json must identify pearl-1"
[ "$(jq -r '.snapshot.script // empty' "$VERSIONS")" = "resources/apply_snapshot.sh" ] || fail "snapshot helper path missing from VERSIONS.json"
[ -n "$(jq -r '.snapshot.providers.utsa.url // empty' "$VERSIONS")" ] || fail "UTSA Pearl snapshot URL missing from VERSIONS.json"
[ -n "$(jq -r '.snapshot.providers.hazen.index_url // empty' "$VERSIONS")" ] || fail "Hazen Pearl snapshot index missing from VERSIONS.json"
[ -n "$(jq -r '.snapshot.providers.hazen.url // empty' "$VERSIONS")" ] || fail "Hazen Pearl snapshot URL missing from VERSIONS.json"

grep -Fq 'Snapshot application is available for Pearl' "$README" || fail "README does not describe the active Pearl snapshot path"
grep -Fq 'UTSA' "$SNAPSHOT_DOC" || fail "snapshot documentation does not describe UTSA"
grep -Fq 'Hazen Network Solutions' "$SNAPSHOT_DOC" || fail "snapshot documentation does not describe Hazen"
grep -Fq '`pearl-1`' "$SNAPSHOT_DOC" || fail "snapshot documentation does not pin the Pearl chain ID"
grep -Fq '`catching_up=false`' "$SNAPSHOT_DOC" || fail "snapshot documentation does not state the Pearl safe-stop precondition"

if grep -Fq 'Snapshot application is currently **disabled for Pearl**' "$README"; then
    fail "README still says Pearl snapshots are disabled"
fi
if grep -Fq 'Snapshot application is currently **disabled** for Gno.land Pearl.' "$SNAPSHOT_DOC"; then
    fail "snapshot guide still says Pearl snapshots are disabled"
fi
if grep -Fq 'Pearl snapshots remain disabled' "$MAIN"; then
    fail "interactive guidelines still say Pearl snapshots are disabled"
fi

echo "SNAPSHOT_DOCS_CONTRACT_OK"
