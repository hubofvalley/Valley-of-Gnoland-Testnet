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

# Exercise the actual helper using a fixed clock; no node or RPC is needed.
run_age_guard() {
    {
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        sed -n '/^check_block_freshness() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'check_block_freshness local_block_age "$1" "$2"'
    } | bash -s -- "$1" "$2"
}

assert_age() {
    local timestamp=$1 now=$2 expected=$3 observed
    observed=$(run_age_guard "$timestamp" "$now")
    [[ "$observed" == "$expected"* ]] || fail "unexpected age result: $observed"
}

# 2026-11-26T06:00:00Z = 1795672800.
assert_age '2026-11-26T06:00:00.123456789Z' 1795672800 'PASS|local_block_age|latest block timestamp is 0 seconds old'
assert_age '2026-11-26T05:55:00Z' 1795672800 'PASS|local_block_age|latest block timestamp is 300 seconds old'
assert_age '2026-11-26T05:54:59Z' 1795672800 'WARN|local_block_age|latest block timestamp is 301 seconds old'
assert_age '2026-11-26T06:00:01Z' 1795672800 'WARN|local_block_age|latest block timestamp is ahead'
assert_age '1970-01-01T00:00:00Z' 1795672800 'WARN|local_block_age|latest block age could not be verified'
assert_age '2026-02-30T00:00:00Z' 1795672800 'WARN|local_block_age|latest block age could not be verified'
assert_age '' 1795672800 'WARN|local_block_age|latest block age could not be verified'
assert_age 'yesterday' 1795672800 'WARN|local_block_age|latest block age could not be verified'
assert_age '2026-11-26T06:00:00Z' '' 'WARN|local_block_age|latest block age could not be verified'

# Execute the production status block with only mocked responses and a fixed clock.
run_status_checks() {
    {
        cat <<'MOCKS'
EXPECTED_CHAIN_ID=onyx-1
GNOLAND_REMOTE=http://local.invalid
PUBLIC_RPC=https://public.invalid
record() { printf '%s|%s|%s\n' "$1" "$2" "$3"; }
# Use environment values rather than curl arguments for the fixtures.
curl() {
    case "$*" in
        *local.invalid/status) printf '%s\n' "$LOCAL_FIXTURE";;
        *public.invalid/status) printf '%s\n' "$PUBLIC_FIXTURE";;
        *) return 1;;
    esac
}
date() {
    if [ "$*" = '-u +%s' ]; then printf '%s\n' 1795672800; else command date "$@"; fi
}
MOCKS
        sed -n '/^check_block_freshness() {/,/^}/p' "$DOCTOR"
        sed -n '/^local_status=/,/^if command -v timedatectl/{ /^if command -v timedatectl/d; p; }' "$DOCTOR"
    } | LOCAL_FIXTURE="$1" PUBLIC_FIXTURE="$2" bash -s
}

fresh='{"result":{"node_info":{"network":"onyx-1"},"sync_info":{"latest_block_time":"2026-11-26T06:00:00Z"}}}'
stale='{"result":{"node_info":{"network":"onyx-1"},"sync_info":{"latest_block_time":"2026-11-26T05:54:59Z"}}}'
wrong='{"result":{"node_info":{"network":"other"},"sync_info":{"latest_block_time":"2026-11-26T06:00:00Z"}}}'
missing='{"result":{"node_info":{"network":"onyx-1"},"sync_info":{}}}'
observed=$(run_status_checks "$stale" "$fresh")
grep -Fq 'WARN|local_block_age|latest block timestamp is 301 seconds old' <<<"$observed" || fail "stale local status not detected"
grep -Fq 'PASS|public_block_age|latest block timestamp is 0 seconds old' <<<"$observed" || fail "fresh public status not detected"
observed=$(run_status_checks "$wrong" "$missing")
if grep -Fq '|local_block_age|' <<<"$observed"; then fail "wrong-chain local timestamp was evaluated"; fi
grep -Fq 'WARN|public_block_age|latest block age could not be verified' <<<"$observed" || fail "missing public timestamp not detected"

echo "NODE_DOCTOR_TEST_OK"
