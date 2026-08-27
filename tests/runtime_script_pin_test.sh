#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/resources/valleyofGnoland.sh"
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "RUNTIME_SCRIPT_PIN_TEST_FAIL: $*" >&2; exit 1; }

runtime_ref=$(sed -n 's/^readonly VALLEY_RUNTIME_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$MAIN")
doctor_ref=$(sed -n 's/^readonly DEFAULT_NODE_DOCTOR_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$DOCTOR")
[ -n "$runtime_ref" ] || fail "VALLEY_RUNTIME_REF must be a full commit SHA"
[ "$doctor_ref" = "$runtime_ref" ] || fail "doctor default ref differs from runtime helper ref"

grep -Fq 'Valley-of-Gnoland-Testnet/${VALLEY_RUNTIME_REF}/${NODE_DOCTOR_RELATIVE_PATH}' "$MAIN" || fail "doctor fallback is not pinned"
grep -Fq 'GNOLAND_NODE_DOCTOR_REF="$VALLEY_RUNTIME_REF" bash "$script_file"' "$MAIN" || fail "doctor fallback does not pass immutable ref"
grep -Fq 'Valley-of-Gnoland-Testnet/${VALLEY_RUNTIME_REF}/${relative_path}' "$MAIN" || fail "helper loader is not pinned"

if grep -Fq 'raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/' "$MAIN"; then
    fail "runtime helpers execute from mutable main"
fi

echo "RUNTIME_SCRIPT_PIN_TEST_OK"
