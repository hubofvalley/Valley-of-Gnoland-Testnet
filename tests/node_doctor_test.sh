#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"

fail() { echo "NODE_DOCTOR_TEST_FAIL: $*" >&2; exit 1; }

version=$(bash "$DOCTOR" --version)
[ "$version" = 'Valley of Gnoland Node Doctor (Pearl) 1.1.0' ] || fail "unexpected version output"

set +e
GNOLAND_NODE_DOCTOR_REF=main bash "$DOCTOR" --version >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "mutable runtime ref should be rejected"

grep -Fq 'EXPECTED_CHAIN_ID="pearl-1"' "$DOCTOR" || fail "Pearl chain guard missing"
grep -Fq 'EXPECTED_RELEASE_COMMIT="c4c72fdd288c757e8da0d93aae867fa479b1b15c"' "$DOCTOR" || fail "release commit guard missing"
grep -Fq 'EXPECTED_GENESIS_SHA256="c45fe60c8c8a1f859d9e4d5aad7ce4d100ff0eb78302e71318ba0de481a8dc91"' "$DOCTOR" || fail "genesis guard missing"
grep -Fq -- '--skip-genesis-sig-verification' "$DOCTOR" || fail "required startup flag check missing"
grep -Fq 'record PASS rpc_unsafe "unsafe RPC endpoints are disabled"' "$DOCTOR" || fail "rpc.unsafe disabled check missing"
grep -Fq 'record FAIL rpc_unsafe "rpc.unsafe is ${rpc_unsafe:-missing}; unsafe RPC endpoints must remain disabled"' "$DOCTOR" || fail "rpc.unsafe fail-closed check missing"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/node/config"
cat >"$TMP/bin/curl" <<'EOF'
#!/bin/sh
printf '{}\n'
EOF
cat >"$TMP/bin/systemctl" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$TMP/bin/timedatectl" <<'EOF'
#!/bin/sh
printf 'no\n'
EOF
chmod +x "$TMP/bin/curl" "$TMP/bin/systemctl" "$TMP/bin/timedatectl"

run_rpc_unsafe_case() {
    local value=$1 expected_level=$2 output
    cat >"$TMP/node/config/config.toml" <<EOF
[rpc]
unsafe = $value
EOF
    set +e
    output=$(PATH="$TMP/bin:$PATH" HOME="$TMP" GNO_SOURCE_DIR="$TMP/missing-source" \
        GNOLAND_TESTNET_HOME="$TMP/node" GNOLAND_GENESIS="$TMP/missing-genesis.json" \
        GNOLAND_TESTNET_SERVICE_NAME="missing-gnoland-testnet" GNOLAND_BIN=/bin/true GNOKEY_BIN=/bin/true \
        bash "$DOCTOR" --json 2>/dev/null)
    set -e
    level=$(printf '%s' "$output" | jq -r '.results[] | select(.code == "rpc_unsafe") | .level')
    [ "$level" = "$expected_level" ] || fail "rpc.unsafe=$value reported $level, expected $expected_level"
}

run_rpc_unsafe_case false PASS
run_rpc_unsafe_case true FAIL

echo "NODE_DOCTOR_TEST_OK"
