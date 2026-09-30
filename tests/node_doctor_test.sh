#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "NODE_DOCTOR_TEST_FAIL: $*" >&2; exit 1; }

version=$(bash "$DOCTOR" --version)
[ "$version" = 'Valley of Gnoland Node Doctor (Onyx) 1.0.0' ] || fail "unexpected version output"

set +e
GNOLAND_NODE_DOCTOR_REF=main bash "$DOCTOR" --version >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "mutable runtime ref should be rejected"

grep -Fq 'EXPECTED_CHAIN_ID="onyx-1"' "$DOCTOR" || fail "Onyx chain guard missing"
grep -Fq 'EXPECTED_RELEASE_COMMIT="5cdbc25fcde0b7569911a4e308ae5d2f6e96c399"' "$DOCTOR" || fail "release commit guard missing"
grep -Fq 'EXPECTED_GENESIS_SHA256="4b006fd7ccdec052865accc84dd29b2b76f8b57b2560789a15eedaa88f0e26c5"' "$DOCTOR" || fail "genesis guard missing"
grep -Fq -- '--skip-genesis-sig-verification' "$DOCTOR" || fail "required startup flag check missing"

echo "NODE_DOCTOR_TEST_OK"
