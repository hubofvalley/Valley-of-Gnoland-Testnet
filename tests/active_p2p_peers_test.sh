#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { printf 'ACTIVE_P2P_PEERS_TEST_FAIL: %s\n' "$*" >&2; exit 1; }

# Exercise only the pure parser: do not run the full doctor or access nodes.
# shellcheck disable=SC1090
source <(sed -n '/^read_active_persistent_peers() {/,/^}/p' "$DOCTOR")
declare -F read_active_persistent_peers >/dev/null || fail "parser function not found"
grep -Fq 'configured_peers=$(read_active_persistent_peers "$CONFIG_FILE")' "$DOCTOR" || fail "doctor does not use active peer parser"

peers=$(sed -n 's/^readonly EXPECTED_PEERS="\([^"]*\)"$/\1/p' "$DOCTOR")
[ -n "$peers" ] || fail "missing expected peers"

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

assert_value() {
    local name=$1 expected=$2 fixture=$3 actual
    printf '%s\n' "$fixture" > "$temp_dir/$name.toml"
    actual=$(read_active_persistent_peers "$temp_dir/$name.toml")
    [ "$actual" = "$expected" ] || fail "$name: expected '$expected', got '$actual'"
}

assert_value valid "$peers" "[p2p]
persistent_peers = \"$peers\""
assert_value trailing_comment "$peers" "[p2p]
persistent_peers = \"$peers\" # verified seeds"
assert_value commented_only "" "[p2p]
# persistent_peers = \"$peers\""
assert_value wrong_section "" "[rpc]
persistent_peers = \"$peers\"
[p2p]
pex = true"
assert_value commented_match_active_wrong "elsewhere" "[p2p]
# persistent_peers = \"$peers\"
persistent_peers = \"elsewhere\""
assert_value duplicate_key "" "[p2p]
persistent_peers = \"$peers\"
persistent_peers = \"elsewhere\""
assert_value duplicate_table "" "[p2p]
persistent_peers = \"$peers\"
[p2p]
pex = true"
assert_value nested_table "" "[p2p.settings]
persistent_peers = \"$peers\"
[p2p]
pex = true"
assert_value unquoted "" "[p2p]
persistent_peers = $peers"
assert_value malformed_suffix "" "[p2p]
persistent_peers = \"$peers\" trailing"

echo "ACTIVE_P2P_PEERS_TEST_OK"
