#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSIONS="$ROOT/VERSIONS.json"
README="$ROOT/README.md"
SNAPSHOT_DOC="$ROOT/docs/snapshots.md"
USAGE="$ROOT/docs/usage.md"
NODE_GUIDE="$ROOT/docs/node-guide.md"
MAIN="$ROOT/resources/valleyofGnoland.sh"
PUBLIC_FILES=("$README" "$USAGE" "$SNAPSHOT_DOC" "$NODE_GUIDE" "$MAIN")

fail() { echo "SNAPSHOT_DOCS_CONTRACT_FAIL: $*" >&2; exit 1; }

[ "$(jq -r '.chain_id // empty' "$VERSIONS")" = "pearl-1" ] || fail "VERSIONS.json must identify pearl-1"
[ "$(jq -r '.snapshot.status // empty' "$VERSIONS")" = "enabled" ] || fail "snapshot status must be enabled"
[ "$(jq -r '.snapshot.script // empty' "$VERSIONS")" = "resources/apply_snapshot.sh" ] || fail "snapshot helper path missing"
[ -n "$(jq -r '.snapshot.providers.utsa.url // empty' "$VERSIONS")" ] || fail "UTSA snapshot URL missing"
[ -n "$(jq -r '.snapshot.providers.hazen.index_url // empty' "$VERSIONS")" ] || fail "Hazen snapshot index missing"
[ "$(jq -r '.snapshot.providers.hazen.required_chain_id // empty' "$VERSIONS")" = "pearl-1" ] || fail "Hazen chain guard metadata missing"

grep -Fq 'Snapshot application is available for Pearl' "$README" || fail "README does not describe active Pearl snapshots"
grep -Fq 'Snapshot application is available for Gno.land Pearl' "$SNAPSHOT_DOC" || fail "snapshot guide does not describe active Pearl snapshots"
grep -Fq 'UTSA' "$SNAPSHOT_DOC" || fail "snapshot guide does not describe UTSA"
grep -Fq 'Hazen Network Solutions' "$SNAPSHOT_DOC" || fail "snapshot guide does not describe Hazen"
grep -Fq '`catching_up=false`' "$SNAPSHOT_DOC" || fail "snapshot guide does not state the safe-stop precondition"
grep -Fq 'Applies a Pearl snapshot from UTSA or Hazen' "$USAGE" || fail "usage guide does not describe option 1c"
grep -Fq 'Snapshot application is available for Pearl through the UTSA and Hazen Network Solutions paths' "$NODE_GUIDE" || fail "manual node guide does not describe active Pearl snapshots"
grep -Fq '1c. Apply Snapshot' "$MAIN" || fail "interactive menu does not expose option 1c"

# Keep disabled claims out of every public surface. This catches a stale
# sentence even when another document correctly describes the active flow.
disabled_claim_re='snapshot[^[:cntrl:]]*(disabled|not available|not supported|fails closed)|disabl(e|es|ed)[^[:cntrl:]]*snapshot|fails closed[^[:cntrl:]]*snapshot'
if disabled_claims=$(grep -Ein "$disabled_claim_re" "${PUBLIC_FILES[@]}" 2>/dev/null); then
    fail "public snapshot surfaces contain a disabled claim:\n$disabled_claims"
fi

echo "SNAPSHOT_DOCS_CONTRACT_OK"
