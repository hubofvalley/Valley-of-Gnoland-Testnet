#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "SAFE_STOP_TEST_FAIL: $*" >&2; exit 1; }

run_snapshot_case() {
    local network=$1 catching_up=$2 expected=$3
    local output rc
    set +e
    output=$(HOME="$TMP/snapshot-home" GNOLAND_REMOTE="http://127.0.0.1:26657" SNAPSHOT="$SNAPSHOT" NETWORK="$network" CATCHING_UP="$catching_up" bash <<'EOS' 2>&1
set -u -o pipefail
mkdir -p "$HOME"
source "$SNAPSHOT"
systemctl() {
    if [ "${1:-}" = "is-active" ]; then return 0; fi
    return 1
}
curl() {
    printf '{"result":{"node_info":{"network":"%s"},"sync_info":{"catching_up":%s}}}\n' "$NETWORK" "$CATCHING_UP"
}
safe_stop_preflight
EOS
    )
    rc=$?
    set -e
    if [ "$expected" = pass ]; then
        [ "$rc" -eq 0 ] || fail "snapshot preflight should pass for network=$network catching_up=$catching_up: $output"
    else
        [ "$rc" -ne 0 ] || fail "snapshot preflight should block for network=$network catching_up=$catching_up"
    fi
    printf '%s' "$output"
}

run_snapshot_case pearl-1 false pass >/dev/null
output=$(run_snapshot_case pearl-1 true block)
[[ "$output" == *"catching_up=true"* ]] || fail "catching-up refusal message missing"
output=$(run_snapshot_case wrong-chain false block)
[[ "$output" == *"did not verify pearl-1"* ]] || fail "network refusal message missing"

set +e
output=$(HOME="$TMP/snapshot-unreachable" GNOLAND_REMOTE="http://127.0.0.1:26657" SNAPSHOT="$SNAPSHOT" bash <<'EOS' 2>&1
set -u -o pipefail
mkdir -p "$HOME"
source "$SNAPSHOT"
systemctl() { [ "${1:-}" = "is-active" ]; }
curl() { return 1; }
safe_stop_preflight
EOS
)
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "unreachable RPC must fail closed"
[[ "$output" == *"reported: unavailable"* ]] || fail "unreachable RPC diagnostic missing"

MOCKBIN="$TMP/mockbin"
UPDATER_HOME="$TMP/updater-home"
mkdir -p "$MOCKBIN" "$UPDATER_HOME/gno" "$UPDATER_HOME/go/bin"
: >"$UPDATER_HOME/.bash_profile"
SERVICE_FILE="$TMP/gnoland.service"
cat >"$SERVICE_FILE" <<EOF
[Service]
User=$(id -un)
WorkingDirectory=$UPDATER_HOME/gno
ExecStart=$UPDATER_HOME/go/bin/gnoland start --chainid pearl-1 --skip-genesis-sig-verification
EOF
cat >"$MOCKBIN/systemctl" <<'EOS'
#!/bin/bash
case "${1:-}" in
    show) printf '%s\n' "$MOCK_SERVICE_FILE" ;;
    is-active) exit 0 ;;
    stop) printf 'STOP CALLED\n' >>"$MOCK_STOP_MARKER"; exit 0 ;;
    *) exit 0 ;;
esac
EOS
cat >"$MOCKBIN/curl" <<'EOS'
#!/bin/bash
printf '%s\n' '{"result":{"node_info":{"network":"pearl-1"},"sync_info":{"catching_up":true}}}'
EOS
chmod +x "$MOCKBIN/systemctl" "$MOCKBIN/curl"

set +e
output=$(PATH="$MOCKBIN:$PATH" HOME="$UPDATER_HOME" GNO_SOURCE_DIR="$UPDATER_HOME/gno" GNOLAND_BIN="$UPDATER_HOME/go/bin/gnoland" GNOKEY_BIN="$UPDATER_HOME/go/bin/gnokey" GNOLAND_REMOTE="http://127.0.0.1:26657" MOCK_SERVICE_FILE="$SERVICE_FILE" MOCK_STOP_MARKER="$TMP/stop-called" bash "$UPDATER" 2>&1)
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "updater must block while catching up"
[[ "$output" == *"catching_up=true"* ]] || fail "updater safe-stop diagnostic missing"
[ ! -e "$TMP/stop-called" ] || fail "updater called systemctl stop despite failed preflight"

grep -Fq 'safe_stop_preflight || return 1' "$SNAPSHOT" || fail "snapshot stop path is not gated"
grep -Fq 'safe_stop_preflight' "$UPDATER" || fail "updater safe-stop gate missing"

echo "SAFE_STOP_TEST_OK"
