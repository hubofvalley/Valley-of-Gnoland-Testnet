#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "ONYX_PRUNE_STRATEGY_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'read_active_prune_strategy() {' "$DOCTOR" ||
    fail "active TOML reader is missing"
grep -Fq 'configured_pruning=$(read_active_prune_strategy "$CONFIG_FILE")' "$DOCTOR" ||
    fail "Node Doctor does not invoke the active reader"
grep -Fq 'record PASS prune' "$DOCTOR" ||
    fail "correct active pruning must pass"
grep -Fq 'record FAIL prune' "$DOCTOR" ||
    fail "missing or different active pruning must fail"
if grep -Fq "grep -Fq 'prune_strategy = \"syncable\"'" "$DOCTOR"; then
    fail "legacy global text match still present"
fi

# Isolate the exact production reader: no node, service, RPC, or key access.
read_strategy() {
    {
        sed -n '/^read_active_prune_strategy() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'read_active_prune_strategy "$1"'
    } | bash -s -- "$1"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cfg="$tmp/config.toml"

assert_case() {
    local label=$1 expected=$2 fixture=$3 observed
    printf '%s' "$fixture" > "$cfg"
    observed=$(read_strategy "$cfg")
    if [ "$observed" != "$expected" ]; then
        fail "$label: expected '$expected', got '$observed'"
    fi
}

assert_case "active required value" "syncable" $'[application]\nprune_strategy = "syncable"\n'
assert_case "whitespace and comment" "syncable" $'  [application] # settings\n  prune_strategy = "syncable" # approved\n'
assert_case "different active value" "nothing" $'[application]\nprune_strategy = "nothing"\n'
assert_case "only commented example" "" $'[application]\n# prune_strategy = "syncable"\n'
assert_case "commented required value and actual drift" "everything" $'[application]\n# prune_strategy = "syncable"\nprune_strategy = "everything"\n'
assert_case "only other section" "" $'[rpc]\nprune_strategy = "syncable"\n'
assert_case "other section cannot override drift" "nothing" $'[rpc]\nprune_strategy = "syncable"\n[application]\nprune_strategy = "nothing"\n'
assert_case "unquoted value is unsupported" "" $'[application]\nprune_strategy = syncable\n'
assert_case "trailing invalid syntax" "" $'[application]\nprune_strategy = "syncable" invalid\n'
assert_case "duplicate active key" "" $'[application]\nprune_strategy = "syncable"\nprune_strategy = "syncable"\n'
assert_case "nested section does not override" "syncable" $'[application]\nprune_strategy = "syncable"\n[application.extra]\nprune_strategy = "nothing"\n'
assert_case "root-level key is not active" "" $'prune_strategy = "syncable"\n[p2p]\npex = true\n'
assert_case "empty value is unverified" "" $'[application]\nprune_strategy = ""\n'
assert_case "unterminated quote is unverified" "" $'[application]\nprune_strategy = "syncable\n'

printf '%s\n' "ONYX_PRUNE_STRATEGY_TEST_OK"
