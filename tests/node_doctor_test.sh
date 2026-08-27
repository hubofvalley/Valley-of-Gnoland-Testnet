#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "NODE_DOCTOR_TEST_FAIL: $*" >&2; exit 1; }

version=$(bash "$DOCTOR" --version)
[ "$version" = 'Valley of Gnoland Node Doctor (Pearl) 1.0.0' ] || fail "unexpected version output"

set +e
GNOLAND_NODE_DOCTOR_REF=main bash "$DOCTOR" --version >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "mutable runtime ref should be rejected"

grep -Fq 'EXPECTED_CHAIN_ID="pearl-1"' "$DOCTOR" || fail "Pearl chain guard missing"
grep -Fq 'EXPECTED_RELEASE_COMMIT="c4c72fdd288c757e8da0d93aae867fa479b1b15c"' "$DOCTOR" || fail "release commit guard missing"
grep -Fq 'EXPECTED_GENESIS_SHA256="c45fe60c8c8a1f859d9e4d5aad7ce4d100ff0eb78302e71318ba0de481a8dc91"' "$DOCTOR" || fail "genesis guard missing"
grep -Fq -- '--skip-genesis-sig-verification' "$DOCTOR" || fail "required startup flag check missing"

echo "NODE_DOCTOR_TEST_OK"
