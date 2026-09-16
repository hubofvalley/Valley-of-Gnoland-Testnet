#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSIONS="$ROOT/VERSIONS.json"
README="$ROOT/README.md"
SNAPSHOT_DOC="$ROOT/docs/snapshots.md"
USAGE="$ROOT/docs/usage.md"
MAIN="$ROOT/resources/valleyofGnoland.sh"

fail() { echo "SNAPSHOT_DOCS_CONTRACT_FAIL: $*" >&2; exit 1; }

[ "$(jq -r '.chain_id // empty' "$VERSIONS")" = "pearl-1" ] || fail "VERSIONS.json must identify pearl-1"
[ "$(jq -r '.snapshot.status // empty' "$VERSIONS")" = "enabled" ] || fail "snapshot status must be enabled"
[ "$(jq -r '.snapshot.script // empty' "$VERSIONS")" = "resources/apply_snapshot.sh" ] || fail "snapshot helper path missing"
[ -n "$(jq -r '.snapshot.providers.utsa.url // empty' "$VERSIONS")" ] || fail "UTSA snapshot URL missing"
[ -n "$(jq -r '.snapshot.providers.hazen.index_url // empty' "$VERSIONS")" ] || fail "Hazen snapshot index missing"
[ "$(jq -r '.snapshot.providers.hazen.required_chain_id // empty' "$VERSIONS")" = "pearl-1" ] || fail "Hazen chain guard metadata missing"

grep -Fq 'Snapshot application is available for Pearl' "$README" || fail "README does not describe active Pearl snapshots"
grep -Fq 'UTSA' "$SNAPSHOT_DOC" || fail "snapshot guide does not describe UTSA"
grep -Fq 'Hazen Network Solutions' "$SNAPSHOT_DOC" || fail "snapshot guide does not describe Hazen"
grep -Fq '`catching_up=false`' "$SNAPSHOT_DOC" || fail "snapshot guide does not state the safe-stop precondition"
grep -Fq 'Applies a Pearl snapshot from UTSA or Hazen' "$USAGE" || fail "usage guide does not describe option 1c"

if grep -Fq 'Snapshot application is currently **disabled for Pearl**' "$README"; then fail "README still says snapshots are disabled"; fi
if grep -Fq 'Snapshot application is currently **disabled** for Gno.land Pearl.' "$SNAPSHOT_DOC"; then fail "snapshot guide still says snapshots are disabled"; fi
if grep -Fq 'Pearl snapshots remain disabled' "$MAIN"; then fail "interactive guidelines still say snapshots are disabled"; fi

echo "SNAPSHOT_DOCS_CONTRACT_OK"
