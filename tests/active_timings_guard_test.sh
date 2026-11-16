#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "ONYX_ACTIVE_CONFIG_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'read_active_config_value() {' "$DOCTOR" || fail "active section reader missing"
for check in 'consensus timeout_commit string' 'consensus peer_gossip_sleep_duration string' 'p2p flush_throttle_timeout string' 'p2p pex bool'; do
    grep -Fq "read_active_config_value \"\$CONFIG_FILE\" $check" "$DOCTOR" || fail "active check missing: $check"
done

# Exercise the production parser in isolation without invoking node, RPC, service, or keys.
read_value() {
    {
        sed -n '/^read_active_config_value() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'read_active_config_value "$1" "$2" "$3" "$4"'
    } | bash -s -- "$cfg" "$1" "$2" "$3"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cfg="$tmp/config.toml"

assert_case() {
    local label=$1 expected=$2 section=$3 key=$4 kind=$5 fixture=$6 observed
    printf '%s' "$fixture" > "$cfg"
    observed=$(read_value "$section" "$key" "$kind")
    [ "$observed" = "$expected" ] || fail "$label: expected '$expected', got '$observed'"
}

assert_case "active timeout" "3s" consensus timeout_commit string $'[consensus]\ntimeout_commit = "3s"\n'
assert_case "active gossip" "10ms" consensus peer_gossip_sleep_duration string $'[consensus]\npeer_gossip_sleep_duration = "10ms"\n'
assert_case "active flush" "10ms" p2p flush_throttle_timeout string $'[p2p]\nflush_throttle_timeout = "10ms"\n'
assert_case "active PEX" "true" p2p pex bool $'[p2p]\npex = true\n'
assert_case "PEX disabled" "false" p2p pex bool $'[p2p]\npex = false\n'
assert_case "whitespace and trailing comments" "3s" consensus timeout_commit string $'  [consensus] # active\n timeout_commit = "3s" # expected\n'
assert_case "comment-only match" "" consensus timeout_commit string $'[consensus]\n# timeout_commit = "3s"\n'
assert_case "comment hides drift" "6s" consensus timeout_commit string $'[consensus]\n# timeout_commit = "3s"\ntimeout_commit = "6s"\n'
assert_case "other section hides drift" "6s" consensus timeout_commit string $'[p2p]\ntimeout_commit = "3s"\n[consensus]\ntimeout_commit = "6s"\n'
assert_case "wrong section only" "" consensus timeout_commit string $'[p2p]\ntimeout_commit = "3s"\n'
assert_case "nested subsection" "" consensus timeout_commit string $'[consensus.subsection]\ntimeout_commit = "3s"\n'
assert_case "nested section does not override" "3s" consensus timeout_commit string $'[consensus]\ntimeout_commit = "3s"\n[consensus.subsection]\ntimeout_commit = "6s"\n'
assert_case "duplicate keys rejected" "" consensus timeout_commit string $'[consensus]\ntimeout_commit = "3s"\ntimeout_commit = "3s"\n'
assert_case "duplicate tables rejected" "" consensus timeout_commit string $'[consensus]\ntimeout_commit = "3s"\n[consensus]\n# duplicate\n'
assert_case "unsupported unquoted string" "" consensus timeout_commit string $'[consensus]\ntimeout_commit = 3s\n'
assert_case "invalid trailing text" "" consensus timeout_commit string $'[consensus]\ntimeout_commit = "3s" junk\n'
assert_case "empty value rejected" "" consensus timeout_commit string $'[consensus]\ntimeout_commit = ""\n'
assert_case "missing quotation rejected" "" consensus timeout_commit string $'[consensus]\ntimeout_commit = "3s\n'
assert_case "PEX string not boolean" "" p2p pex bool $'[p2p]\npex = "true"\n'
assert_case "PEX comment-only match" "" p2p pex bool $'[p2p]\n# pex = true\n'
assert_case "PEX duplicate rejected" "" p2p pex bool $'[p2p]\npex = true\npex = false\n'
assert_case "PEX wrong section rejected" "" p2p pex bool $'[rpc]\npex = true\n'

printf '%s\n' "ONYX_ACTIVE_CONFIG_TEST_OK"
