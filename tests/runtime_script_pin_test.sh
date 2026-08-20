#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN_SCRIPT="$REPO_ROOT/resources/valleyofGnoland.sh"
DOCTOR_LOADER="$REPO_ROOT/resources/gnoland_node_doctor.sh"

fail() {
    echo "Runtime script pin test failed: $*" >&2
    exit 1
}

runtime_ref=$(sed -n 's/^readonly VALLEY_RUNTIME_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$MAIN_SCRIPT")
[ -n "$runtime_ref" ] || fail "VALLEY_RUNTIME_REF is missing or is not a full commit SHA"

if grep -Fq 'raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/' "$MAIN_SCRIPT"; then
    fail "main script still executes runtime helpers from mutable main"
fi

doctor_function=$(sed -n '/^run_node_doctor_script() {$/,/^}$/p' "$MAIN_SCRIPT")
repo_function=$(sed -n '/^function run_repository_script() {$/,/^}$/p' "$MAIN_SCRIPT")

printf '%s\n' "$doctor_function" | grep -Fq 'Valley-of-Gnoland-Testnet/${VALLEY_RUNTIME_REF}/${NODE_DOCTOR_RELATIVE_PATH}' ||
    fail "Node Doctor fallback is not pinned to VALLEY_RUNTIME_REF"
printf '%s\n' "$doctor_function" | grep -Fq 'GNOLAND_NODE_DOCTOR_REF="$VALLEY_RUNTIME_REF" bash "$script_file"' ||
    fail "Node Doctor fallback does not pass the immutable ref into the loader"
printf '%s\n' "$repo_function" | grep -Fq 'Valley-of-Gnoland-Testnet/${VALLEY_RUNTIME_REF}/${relative_path}' ||
    fail "runtime helper loader is not pinned to VALLEY_RUNTIME_REF"

loader_ref=$(sed -n 's/^readonly DEFAULT_NODE_DOCTOR_REF="\([0-9a-f]\{40\}\)"$/\1/p' "$DOCTOR_LOADER")
[ "$loader_ref" = "$runtime_ref" ] || fail "Node Doctor default ref differs from runtime helper ref"
if grep -Fq 'GNOLAND_NODE_DOCTOR_REF:-main' "$DOCTOR_LOADER"; then
    fail "Node Doctor still defaults to mutable main"
fi

TEST_ROOT=$(mktemp -d)
cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

set +e
GNOLAND_NODE_DOCTOR_REF=main bash "$DOCTOR_LOADER" --version >"$TEST_ROOT/invalid-ref.log" 2>&1
invalid_ref_rc=$?
set -e
[ "$invalid_ref_rc" -eq 2 ] || fail "mutable Node Doctor ref should be rejected with exit code 2"

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/run"
cp "$MAIN_SCRIPT" "$TEST_ROOT/run/valleyofGnoland.sh"
cat > "$TEST_ROOT/bin/curl" <<'EOF_CURL'
#!/bin/bash
set -e
out=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) out=$2; shift 2 ;;
        -*) shift ;;
        *) url=$1; shift ;;
    esac
done
printf '%s\n' "$url" > "$MOCK_CURL_URL_FILE"
cat > "$out" <<'EOF_SCRIPT'
#!/bin/bash
[ "${GNOLAND_NODE_DOCTOR_REF:-}" = "${EXPECTED_NODE_DOCTOR_REF:-}" ] || exit 90
[ "${1:-}" = "--version" ] && printf '%s\n' 'mock-doctor'
EOF_SCRIPT
EOF_CURL
chmod +x "$TEST_ROOT/bin/curl"

MOCK_CURL_URL_FILE="$TEST_ROOT/url" \
EXPECTED_NODE_DOCTOR_REF="$runtime_ref" \
PATH="$TEST_ROOT/bin:/usr/bin:/bin" \
bash "$TEST_ROOT/run/valleyofGnoland.sh" doctor --version > "$TEST_ROOT/output"

grep -Fxq 'mock-doctor' "$TEST_ROOT/output" || fail "doctor fallback did not execute the downloaded fixture"
grep -Fq "/$runtime_ref/resources/gnoland_node_doctor.sh" "$TEST_ROOT/url" ||
    fail "doctor fallback did not request the pinned commit"
if grep -Fq '/main/' "$TEST_ROOT/url"; then
    fail "doctor fallback requested mutable main"
fi

echo "RUNTIME_SCRIPT_PIN_TEST_OK"
