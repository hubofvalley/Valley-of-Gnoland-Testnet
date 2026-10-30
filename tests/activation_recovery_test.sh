#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
UPDATER="$ROOT/resources/gnoland_update.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "ACTIVATION_RECOVERY_TEST_FAIL: $*" >&2; exit 1; }

HOME_DIR="$TMP/home"
SOURCE_DIR="$HOME_DIR/gno"
NODE_DIR="$SOURCE_DIR/gnoland-data"
BIN_DIR="$HOME_DIR/go/bin"
MOCKBIN="$TMP/mockbin"
mkdir -p "$SOURCE_DIR/gnovm/stdlibs/errors" "$NODE_DIR/config" "$BIN_DIR" "$MOCKBIN"
: >"$HOME_DIR/.bash_profile"

cat >"$BIN_DIR/gnoland" <<'OLD_GNOLAND'
#!/bin/sh
echo 'gnoland version: v1.6.0-rc.1'
OLD_GNOLAND
cat >"$BIN_DIR/gnokey" <<'OLD_GNOKEY'
#!/bin/sh
echo 'gnokey version: v1.6.0-rc.1'
OLD_GNOKEY
chmod +x "$BIN_DIR/gnoland" "$BIN_DIR/gnokey"

cat >"$NODE_DIR/config/config.toml" <<'CFG'
[rpc]
laddr = "tcp://127.0.0.1:26657"
CFG

/usr/bin/git -C "$SOURCE_DIR" init -q
/usr/bin/git -C "$SOURCE_DIR" config user.name fixture
/usr/bin/git -C "$SOURCE_DIR" config user.email fixture@example.invalid
printf 'old source\n' >"$SOURCE_DIR/source-marker"
/usr/bin/git -C "$SOURCE_DIR" add source-marker
/usr/bin/git -C "$SOURCE_DIR" commit -qm fixture
OLD_SOURCE=$(/usr/bin/git -C "$SOURCE_DIR" rev-parse HEAD)
export OLD_SOURCE

SERVICE_FILE="$TMP/gnoland-testnet.service"
cat >"$SERVICE_FILE" <<EOF_SERVICE
[Service]
User=$(id -un)
WorkingDirectory=$SOURCE_DIR
ExecStart=$BIN_DIR/gnoland start --data-dir $NODE_DIR --chainid onyx-1 --skip-genesis-sig-verification
EOF_SERVICE

cat >"$MOCKBIN/systemctl" <<'MOCK_SYSTEMCTL'
#!/bin/bash
case "$1" in
    show)
        printf '%s\n' "$MOCK_SERVICE_FILE"
        ;;
    is-active)
        printf 'active\n'
        exit 0
        ;;
    stop)
        printf 'stop\n' >>"$MOCK_EVENTS"
        ;;
    restart)
        if [ "${MOCK_FAIL_PRE_RESTART:-0}" != 1 ] && [ ! -e "$MOCK_RESTART_FAILED" ]; then
            : >"$MOCK_RESTART_FAILED"
            printf 'restart-failed\n' >>"$MOCK_EVENTS"
            exit 1
        fi
        printf 'recovery-restart\n' >>"$MOCK_EVENTS"
        ;;
    *)
        ;;
esac
MOCK_SYSTEMCTL

cat >"$MOCKBIN/sudo" <<'MOCK_SUDO'
#!/bin/bash
if [ "$1" = "-n" ]; then shift; fi
exec "$@"
MOCK_SUDO

cat >"$MOCKBIN/git" <<'MOCK_GIT'
#!/bin/bash
case "$*" in
    *ls-remote*)
        printf '%s\trefs/tags/v1.7.0-rc.1^{}\n' e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319
        ;;
    *remote*get-url*origin*|*remote*set-url*origin*|*remote*add*origin*)
        ;;
    *fetch*--depth*origin*)
        ;;
    *rev-parse*FETCH_HEAD*)
        printf '%s\n' 5cdbc25fcde0b7569911a4e308ae5d2f6e96c399
        ;;
    *rev-parse*HEAD*)
        if [ -e "$MOCK_GIT_STATE" ]; then
            printf '%s\n' 5cdbc25fcde0b7569911a4e308ae5d2f6e96c399
        else
            printf '%s\n' "$OLD_SOURCE"
        fi
        ;;
    *status*--porcelain*)
        ;;
    *checkout*--detach*--force*FETCH_HEAD*)
        printf 'new source\n' >"$GNO_SOURCE_DIR/source-marker"
        : >"$MOCK_GIT_STATE"
        if [ "${MOCK_FAIL_PRE_RESTART:-0}" = 1 ]; then
            printf 'checkout-failed\n' >>"$MOCK_EVENTS"
            exit 1
        fi
        ;;
    *checkout*--detach*--force*)
        printf 'old source\n' >"$GNO_SOURCE_DIR/source-marker"
        rm -f "$MOCK_GIT_STATE"
        ;;
    *)
        /usr/bin/git "$@"
        ;;
esac
MOCK_GIT

cat >"$MOCKBIN/curl" <<'MOCK_CURL'
#!/bin/bash
out=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) out=$2; shift 2 ;;
        http://*|https://*) url=$1; shift ;;
        *) shift ;;
    esac
done
if [[ "$url" == */status ]]; then
    printf '%s\n' '{"result":{"node_info":{"network":"onyx-1"},"sync_info":{"catching_up":false}}}'
    exit 0
fi
if [[ "$url" == *gnoland_linux_amd64 ]]; then
    printf '%s\n' '#!/bin/sh' 'echo "gnoland version: v1.7.0-rc.1"' >"$out"
elif [[ "$url" == *gnokey_linux_amd64 ]]; then
    printf '%s\n' '#!/bin/sh' 'echo "gnokey version: v1.7.0-rc.1"' >"$out"
else
    echo "unexpected fixture URL: $url" >&2
    exit 1
fi
chmod +x "$out"
MOCK_CURL

cat >"$MOCKBIN/sha256sum" <<'MOCK_SHA'
#!/bin/bash
cat >/dev/null
printf '%s\n' 'fixture: OK'
MOCK_SHA
chmod +x "$MOCKBIN/systemctl" "$MOCKBIN/sudo" "$MOCKBIN/git" "$MOCKBIN/curl" "$MOCKBIN/sha256sum"

events="$TMP/events"
restart_failed="$TMP/restart-failed"
git_state="$TMP/git-state"
set +e
PATH="$MOCKBIN:$PATH" HOME="$HOME_DIR" GNO_SOURCE_DIR="$SOURCE_DIR" GNOLAND_TESTNET_HOME="$NODE_DIR" GNOROOT="$SOURCE_DIR" GNOLAND_BIN="$BIN_DIR/gnoland" GNOKEY_BIN="$BIN_DIR/gnokey" GNOLAND_TESTNET_SERVICE_NAME=gnoland-testnet MOCK_SERVICE_FILE="$SERVICE_FILE" MOCK_EVENTS="$events" MOCK_RESTART_FAILED="$restart_failed" MOCK_GIT_STATE="$git_state" bash "$UPDATER" >"$TMP/output" 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then cat "$TMP/output" >&2; fail "forced activation failure must return non-zero"; fi
cat "$TMP/output" >&2
grep -Fxq stop "$events" || fail "maintenance stop was not attempted"
if [ "${MOCK_FAIL_PRE_RESTART:-0}" = 1 ]; then
    grep -Fxq checkout-failed "$events" || fail "forced pre-restart activation failure was not observed"
    if grep -Fxq restart-failed "$events"; then
        fail "pre-restart failure unexpectedly reached the restart failure"
    fi
else
    grep -Fxq restart-failed "$events" || fail "forced first restart failure was not observed"
fi
grep -Fxq recovery-restart "$events" || fail "recovery restart was not attempted"
grep -Fxq 'old source' "$SOURCE_DIR/source-marker" || fail "old source was not restored"
grep -Fq 'gnoland version: v1.6.0-rc.1' "$BIN_DIR/gnoland" || fail "old gnoland binary was not restored"
grep -Fq 'gnokey version: v1.6.0-rc.1' "$BIN_DIR/gnokey" || fail "old gnokey binary was not restored"

echo "ACTIVATION_RECOVERY_TEST_OK"
