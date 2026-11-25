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


# Exercise the full doctor with an isolated home and mocked system commands.
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home" "$fixture/data"
printf '[Service]\nExecStart=/usr/bin/gnoland start --chainid onyx-1 --log-level info\n' > "$fixture/gnoland.service"
cat > "$fixture/bin/systemctl" <<'MOCK'
#!/bin/bash
case "$*" in
    *" -p FragmentPath "*) printf '%s\n' "$TEST_SERVICE_FILE" ;;
    *" -p ExecStart "*) printf '%s\n' "$TEST_EFFECTIVE_EXEC"; exit "${TEST_EXEC_STATUS:-0}" ;;
    *) exit 1 ;;
esac
MOCK
printf '#!/bin/bash\nexit 1\n' > "$fixture/bin/curl"
cp "$fixture/bin/curl" "$fixture/bin/timedatectl"
chmod +x "$fixture/bin/"*
export TEST_SERVICE_FILE="$fixture/gnoland.service"

check_exec() {
    local expected=$1 command=$2 status=${3:-0} output
    output=$(HOME="$fixture/home" PATH="$fixture/bin:$PATH" \
        GNOLAND_TESTNET_HOME="$fixture/data" GNO_SOURCE_DIR="$fixture/source" \
        GNOLAND_GENESIS="$fixture/missing-genesis" GNOLAND_BIN="$fixture/missing-gnoland" \
        GNOKEY_BIN="$fixture/missing-gnokey" GNOLAND_TESTNET_SERVICE_NAME=fixture \
        TEST_EFFECTIVE_EXEC="$command" TEST_EXEC_STATUS="$status" \
        bash "$DOCTOR" 2>&1) || true
    grep -Eq "^\[$expected\][[:space:]]+service_log_level[[:space:]]" <<< "$output" ||
        fail "expected $expected service_log_level for $command"
}
check_flags() {
    check_exec "$1" "{ path=/usr/bin/gnoland ; argv[]=/usr/bin/gnoland start $2 ; ignore_errors=no ; }"
}
check_flags PASS '--log-level info'
check_flags PASS '-log-level=warn'
check_flags PASS '--log-level error'
check_flags WARN '--log-level debug'
check_flags WARN ''
check_flags WARN '--log-level info --log-level'
check_flags WARN '--log-level info --log-level debug'
check_flags WARN '--log-level trace'
check_flags WARN '--log-level $LEVEL'
check_flags WARN '-- --log-level info'
check_exec WARN '{ path=/bin/bash ; argv[]=/bin/bash start --log-level info ; ignore_errors=no ; }'
check_exec WARN '{ path=/usr/bin/gnoland ; argv[]=/usr/bin/gnoland start --log-level info ; ignore_errors=no ; }' 1

check_exec WARN '{ path=/usr/bin/gnoland ; argv[]=    ; ignore_errors=no ; }'
check_exec WARN '{ path=/bin/bash ; argv[]=/usr/bin/gnoland start --log-level info ; ignore_errors=no ; }'

echo "NODE_DOCTOR_TEST_OK"
