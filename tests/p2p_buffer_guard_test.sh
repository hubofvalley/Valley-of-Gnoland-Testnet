#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "ONYX_P2P_BUFFER_TEST_FAIL: $*" >&2; exit 1; }

grep -Fq 'check_p2p_buffer_limits "$CONFIG_FILE"' "$DOCTOR" || fail "Node Doctor call missing"

# Exercise the real production parser in isolation: no service, RPC or keys.
probe() {
    {
        sed -n '/^check_p2p_buffer_limits() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        printf '%s\n' 'check_p2p_buffer_limits "$1"'
    } | bash -s -- "$cfg"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cfg="$tmp/config.toml"
assert_result() {
    local label=$1 expected=$2 observed
    observed=$(probe)
    printf '%s\n' "$observed" | grep -Fq "$expected" || fail "$label: missing '$expected' in '$observed'"
}

printf '[p2p]\n' > "$cfg"
assert_result 'default receive' 'PASS|p2p_max_recv_buffer_bytes|'
assert_result 'default send' 'PASS|p2p_max_send_buffer_bytes|'

printf '[p2p]\nmax_recv_buffer_bytes = 8454144\nmax_send_buffer_bytes = 20971520 # upstream default\n' > "$cfg"
assert_result 'receive at minimum' 'PASS|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes=8454144'
assert_result 'send default' 'PASS|p2p_max_send_buffer_bytes|max_send_buffer_bytes=20971520'

printf '[p2p]\nmax_recv_buffer_bytes = 8454143\nmax_send_buffer_bytes = 1\n' > "$cfg"
assert_result 'receive below minimum' 'WARN|p2p_max_recv_buffer_bytes|v1.7.1-rc.1 rejects max_recv_buffer_bytes=8454143'
assert_result 'send below minimum' 'WARN|p2p_max_send_buffer_bytes|v1.7.1-rc.1 rejects max_send_buffer_bytes=1'

printf '[p2p]\nmax_recv_buffer_bytes = 0\nmax_send_buffer_bytes = 0\n' > "$cfg"
assert_result 'receive disabled' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes=0 is accepted'
assert_result 'send disabled' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes=0 is accepted'

printf '[rpc]\nmax_recv_buffer_bytes = 2\n[p2p]\n# max_send_buffer_bytes = 1\n' > "$cfg"
assert_result 'ignore other section' 'PASS|p2p_max_recv_buffer_bytes|'
assert_result 'ignore comment' 'PASS|p2p_max_send_buffer_bytes|'

printf '[p2p]\nmax_recv_buffer_bytes = "8454144"\nmax_send_buffer_bytes = 3 # unsafe\n' > "$cfg"
assert_result 'quoted int' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'
assert_result 'inline comment' 'WARN|p2p_max_send_buffer_bytes|v1.7.1-rc.1 rejects max_send_buffer_bytes=3'

printf '[p2p]\nmax_recv_buffer_bytes = 20971520\nmax_recv_buffer_bytes = 20971520\n' > "$cfg"
assert_result 'duplicate key' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'

printf '[p2p]\nmax_send_buffer_bytes = 20971520\n[p2p]\n' > "$cfg"
assert_result 'duplicate p2p section' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'

printf '[rpc]\nmax_send_buffer_bytes = 20971520\n' > "$cfg"
assert_result 'missing p2p section' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'

printf '[p2p]\nmax_recv_buffer_bytes = -1\nmax_send_buffer_bytes = 9223372036854775808\n' > "$cfg"
assert_result 'negative' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'
assert_result 'overflow' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'

printf '[p2p]\nmax_recv_buffer_bytes = 8454144 junk\nmax_send_buffer_bytes = 08454144\n' > "$cfg"
assert_result 'junk suffix' 'WARN|p2p_max_recv_buffer_bytes|max_recv_buffer_bytes cannot be verified'
assert_result 'leading zero' 'WARN|p2p_max_send_buffer_bytes|max_send_buffer_bytes cannot be verified'

printf 'ONYX_P2P_BUFFER_TEST_OK\n'
