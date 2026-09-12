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

# A healthy node must remain running if artifact staging fails. Mock the source
# fetch as successful, then fail the first release download before the stop line.
mkdir -p "$UPDATER_HOME/gno/.git"
cat >"$MOCKBIN/git" <<'EOS'
#!/bin/bash
case "$*" in
    *"remote get-url origin"*) exit 0 ;;
    *"remote set-url origin"*) exit 0 ;;
    *"fetch --depth 1 origin"*) exit 0 ;;
    *"rev-parse FETCH_HEAD"*) printf '%s\n' "$MOCK_RELEASE_COMMIT" ;;
    *) exit 0 ;;
esac
EOS
cat >"$MOCKBIN/curl" <<'EOS'
#!/bin/bash
case "$*" in
    *"/status"*)
        printf '%s\n' '{"result":{"node_info":{"network":"pearl-1"},"sync_info":{"catching_up":false}}}'
        ;;
    *) exit 22 ;;
esac
EOS
chmod +x "$MOCKBIN/git" "$MOCKBIN/curl"
rm -f "$TMP/stop-called"

set +e
output=$(PATH="$MOCKBIN:$PATH" HOME="$UPDATER_HOME" GNO_SOURCE_DIR="$UPDATER_HOME/gno" GNOLAND_BIN="$UPDATER_HOME/go/bin/gnoland" GNOKEY_BIN="$UPDATER_HOME/go/bin/gnokey" GNOLAND_REMOTE="http://127.0.0.1:26657" MOCK_SERVICE_FILE="$SERVICE_FILE" MOCK_STOP_MARKER="$TMP/stop-called" MOCK_RELEASE_COMMIT="c4c72fdd288c757e8da0d93aae867fa479b1b15c" bash "$UPDATER" 2>&1)
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "updater should fail when release artifact staging fails"
[ ! -e "$TMP/stop-called" ] || fail "updater stopped the service before artifact staging completed"

# Pin the maintenance ordering structurally: network fetches and checksum
# verification happen before stop; source activation happens after stop; and the
# sync-state guard is rechecked immediately before the maintenance boundary.
mapfile -t preflight_lines < <(grep -n '^safe_stop_preflight$' "$UPDATER" | cut -d: -f1)
[ "${#preflight_lines[@]}" -eq 2 ] || fail "updater must run safe-stop preflight twice"
fetch_line=$(grep -nF 'git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "$RELEASE_COMMIT"' "$UPDATER" | cut -d: -f1)
gnoland_checksum_line=$(grep -nF 'echo "${GNOLAND_SHA256}  $tmpdir/gnoland" | sha256sum -c -' "$UPDATER" | cut -d: -f1)
gnokey_checksum_line=$(grep -nF 'echo "${GNOKEY_SHA256}  $tmpdir/gnokey" | sha256sum -c -' "$UPDATER" | cut -d: -f1)
stop_line=$(grep -nF 'sudo systemctl stop "$GNOLAND_SERVICE_NAME"' "$UPDATER" | cut -d: -f1)
checkout_line=$(grep -nF 'git -C "$GNO_SOURCE_DIR" checkout --detach --force FETCH_HEAD' "$UPDATER" | cut -d: -f1)

[ -n "$fetch_line" ] && [ -n "$gnoland_checksum_line" ] && [ -n "$gnokey_checksum_line" ] && [ -n "$stop_line" ] && [ -n "$checkout_line" ] || fail "updater staging markers missing"
(( fetch_line < stop_line )) || fail "source fetch must finish before service stop"
(( gnoland_checksum_line < stop_line )) || fail "gnoland checksum must verify before service stop"
(( gnokey_checksum_line < stop_line )) || fail "gnokey checksum must verify before service stop"
(( preflight_lines[1] < stop_line )) || fail "second safe-stop preflight must run before service stop"
(( checkout_line > stop_line )) || fail "source checkout should remain inside the local activation window"

grep -Fq 'safe_stop_preflight || return 1' "$SNAPSHOT" || fail "snapshot stop path is not gated"
grep -Fq 'safe_stop_preflight' "$UPDATER" || fail "updater safe-stop gate missing"

echo "SAFE_STOP_TEST_OK"
