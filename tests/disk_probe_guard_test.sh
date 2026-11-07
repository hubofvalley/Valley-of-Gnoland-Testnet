#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "DISK_PROBE_TEST_FAIL: $*" >&2; exit 1; }

# Exercise the exact read-only disk check without running the Doctor against a
# live service, hashing a genesis file, or contacting either RPC endpoint.
disk_check=$(sed -n '/^check_disk_capacity() {/,/^}/p' "$DOCTOR")
[ -n "$disk_check" ] || fail "disk capacity function was not found"
eval "$disk_check"

record() { OBSERVED="$1|$2|$3"; }

# A Bash function shadows the df executable; no filesystem or node probes run.
df() {
    case "$PROBE_MODE" in
        enough)
            printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted' \
                'fixture 40000000 1 20971520 1% /'
            ;;
        low)
            printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted' \
                'fixture 40000000 1 20971519 1% /'
            ;;
        failed) return 7 ;;
        empty) return 0 ;;
        invalid)
            printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted' \
                'fixture 40000000 1 unavailable 1% /'
            ;;
        oversized)
            printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted' \
                'fixture 40000000 1 999999999999999999999 1% /'
            ;;
        *) fail "unrecognized fixture $PROBE_MODE" ;;
    esac
}

GNOLAND_TESTNET_HOME="$ROOT"
run_case() {
    PROBE_MODE="$1"
    OBSERVED=""
    check_disk_capacity
    [ "$OBSERVED" = "$2" ] || fail "$PROBE_MODE: got '$OBSERVED', expected '$2'"
}

run_case enough 'PASS|disk|node filesystem has at least 20 GiB free'
run_case low 'WARN|disk|less than 20 GiB free on the node filesystem'
run_case failed 'WARN|disk|node filesystem free capacity could not be verified'
run_case empty 'WARN|disk|node filesystem free capacity could not be verified'
run_case invalid 'WARN|disk|node filesystem free capacity could not be verified'
run_case oversized 'WARN|disk|node filesystem free capacity could not be verified'

GNOLAND_TESTNET_HOME="$ROOT/nonexistent-disk-probe-fixture-dir"
PROBE_MODE=failed
OBSERVED=""
check_disk_capacity
[ -z "$OBSERVED" ] || fail "missing node home should not report disk health"

echo "DISK_PROBE_TEST_OK"
