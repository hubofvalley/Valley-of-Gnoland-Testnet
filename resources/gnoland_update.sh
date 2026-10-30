#!/bin/bash

set -Eeuo pipefail

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

readonly RELEASE_COMMIT="5cdbc25fcde0b7569911a4e308ae5d2f6e96c399"
readonly BINARY_RELEASE_TAG="v1.7.0-rc.1"
readonly BINARY_RELEASE_COMMIT="e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319"
readonly GNOLAND_SHA256="df61577df813d18184d9bfc15f8f28854f37c35bae659bac857d5cae388ea9fa"
readonly GNOKEY_SHA256="6e0fdeed8829865add8b6c8efef41466ae1f05d0598618b02f67533fe582a643"
GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME:-gnoland-testnet}
GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME%.service}
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_TESTNET_HOME=${GNOLAND_TESTNET_HOME:-$GNO_SOURCE_DIR/gnoland-data}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
OS_USER=$(id -un)
SERVICE_FILE=$(systemctl show "$GNOLAND_TESTNET_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
SERVICE_WAS_ACTIVE=0
ACTIVATION_ATTEMPTED=0
ACTIVATION_SUCCEEDED=0
PREVIOUS_SOURCE_COMMIT=""
PREVIOUS_GNOLAND_BACKUP=""
PREVIOUS_GNOKEY_BACKUP=""

canonical_path() {
    realpath -m -- "$1"
}

extract_service_data_dir() {
    local exec_line=$1
    if [[ "$exec_line" =~ (^|[[:space:]])--data-dir=([^[:space:]]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[2]}"
    elif [[ "$exec_line" =~ (^|[[:space:]])--data-dir[[:space:]]+([^[:space:]]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[2]}"
    fi
}

if [ -n "${SUDO_USER:-}" ]; then
    echo "Run the updater as the node OS user, not with sudo." >&2
    exit 1
fi

for instance_path in "$GNO_SOURCE_DIR" "$GNOLAND_TESTNET_HOME" "$GNOROOT" "$GNOLAND_BIN" "$GNOKEY_BIN"; do
    CANONICAL_HOME=$(realpath -m "$HOME")
    CANONICAL_PATH=$(realpath -m "$instance_path")
    case "$CANONICAL_PATH" in
        "$CANONICAL_HOME"/*) ;;
        *) echo "Unsafe instance path outside $HOME: $instance_path" >&2; exit 1 ;;
    esac
done

CANONICAL_HOME=$(canonical_path "$HOME")
CANONICAL_SOURCE=$(canonical_path "$GNO_SOURCE_DIR")
CANONICAL_TESTNET_HOME=$(canonical_path "$GNOLAND_TESTNET_HOME")
case "$CANONICAL_TESTNET_HOME" in
    /|"$CANONICAL_HOME"|"$CANONICAL_SOURCE")
        echo "Unsafe GNOLAND_TESTNET_HOME rejected: $CANONICAL_TESTNET_HOME" >&2
        exit 1
        ;;
    "$CANONICAL_HOME"/*) ;;
    *)
        echo "GNOLAND_TESTNET_HOME must stay inside $HOME." >&2
        exit 1
        ;;
esac
GNOLAND_TESTNET_HOME=$CANONICAL_TESTNET_HOME

validate_service_target() {
    local unit_user unit_workdir unit_exec service_data_dir
    if [ -z "$SERVICE_FILE" ]; then
        echo "Update blocked: cannot prove the selected service targets this testnet instance." >&2
        return 1
    fi
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Cannot inspect existing service: $SERVICE_FILE" >&2
        return 1
    fi
    unit_user=$(sed -n 's/^User=//p' "$SERVICE_FILE" | tail -n 1)
    unit_workdir=$(sed -n 's/^WorkingDirectory=//p' "$SERVICE_FILE" | tail -n 1)
    unit_exec=$(sed -n 's/^ExecStart=//p' "$SERVICE_FILE" | tail -n 1)
    if [ "$unit_user" != "$OS_USER" ] || [ "$unit_workdir" != "$GNO_SOURCE_DIR" ]; then
        echo "$GNOLAND_TESTNET_SERVICE_NAME.service belongs to another instance." >&2
        return 1
    fi
    service_data_dir=$(extract_service_data_dir "$unit_exec")
    if [ -z "$service_data_dir" ] || [ "$(canonical_path "$service_data_dir")" != "$GNOLAND_TESTNET_HOME" ]; then
        echo "Update blocked: service --data-dir does not match GNOLAND_TESTNET_HOME." >&2
        echo "Existing --data-dir=${service_data_dir:-missing}, requested --data-dir=$GNOLAND_TESTNET_HOME" >&2
        return 1
    fi
    if ! grep -Fq -- '--chainid onyx-1' "$SERVICE_FILE"; then
        echo "Update blocked: this service is not configured for onyx-1." >&2
        echo "Use Deploy/Re-deploy to perform the Pearl -> Onyx fresh-chain migration first." >&2
        return 1
    fi
    if ! grep -Fq -- '--skip-genesis-sig-verification' "$SERVICE_FILE"; then
        echo "Update blocked: Onyx requires --skip-genesis-sig-verification in ExecStart." >&2
        return 1
    fi
}

if [[ ! "$GNOLAND_TESTNET_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
    echo "Invalid Gnoland service name: $GNOLAND_TESTNET_SERVICE_NAME" >&2
    exit 1
fi

validate_service_target

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "The verified prebuilt updater currently supports Linux amd64 only." >&2
    exit 1
fi

verify_binary_release_metadata() {
    local tag_commit
    if ! tag_commit=$(git ls-remote https://github.com/gnolang/gno.git "refs/tags/${BINARY_RELEASE_TAG}^{}" | awk 'NR == 1 { print $1 }'); then
        echo "Unable to read official Gno release metadata for ${BINARY_RELEASE_TAG}." >&2
        return 1
    fi
    if [ "$tag_commit" != "$BINARY_RELEASE_COMMIT" ]; then
        echo "Unexpected Gno binary release commit for ${BINARY_RELEASE_TAG}: ${tag_commit:-unavailable}." >&2
        echo "Expected: $BINARY_RELEASE_COMMIT" >&2
        return 1
    fi
}

verify_staged_binary_versions() {
    local gnoland_path=$1 gnokey_path=$2 gnoland_version gnokey_version
    if ! gnoland_version=$(GNOROOT="$GNO_SOURCE_DIR" "$gnoland_path" version 2>/dev/null); then
        echo "Unable to execute staged gnoland version check." >&2
        return 1
    fi
    if [ "$gnoland_version" != "gnoland version: $BINARY_RELEASE_TAG" ]; then
        echo "Staged gnoland reports an unexpected version: ${gnoland_version:-unavailable}." >&2
        echo "Expected: gnoland version: $BINARY_RELEASE_TAG" >&2
        return 1
    fi
    if ! gnokey_version=$(GNOROOT="$GNO_SOURCE_DIR" "$gnokey_path" version 2>/dev/null); then
        echo "Unable to execute staged gnokey version check." >&2
        return 1
    fi
    if [ "$gnokey_version" != "gnokey version: $BINARY_RELEASE_TAG" ]; then
        echo "Staged gnokey reports an unexpected version: ${gnokey_version:-unavailable}." >&2
        echo "Expected: gnokey version: $BINARY_RELEASE_TAG" >&2
        return 1
    fi
}

get_local_rpc_url() {
    local cfg="$GNOLAND_TESTNET_HOME/config/config.toml" port=""
    if [ -f "$cfg" ]; then
        port=$(awk -F: '
            /^[[:space:]]*\[rpc\][[:space:]]*$/ {in_rpc=1; next}
            /^[[:space:]]*\[/ {in_rpc=0}
            in_rpc && /^[[:space:]]*laddr = "tcp:\/\// {
                gsub(/".*/, "", $NF)
                print $NF
                exit
            }
        ' "$cfg")
    fi
    echo "http://127.0.0.1:${port:-26657}"
}

post_start_health_check() {
    local rpc_url status_json network catching_up version

    if ! version=$(GNOROOT="$GNO_SOURCE_DIR" "$GNOLAND_BIN" version 2>/dev/null); then
        echo "Post-start validation failed: gnoland version could not be read." >&2
        return 1
    fi
    if [ "$version" != "gnoland version: $BINARY_RELEASE_TAG" ]; then
        echo "Post-start validation failed: unexpected gnoland version: ${version:-unavailable}." >&2
        return 1
    fi

    rpc_url=$(get_local_rpc_url)
    for _ in $(seq 1 120); do
        if sudo systemctl is-active --quiet "$GNOLAND_TESTNET_SERVICE_NAME"; then
            status_json=$(curl -m 5 -fsS "${rpc_url%/}/status" 2>/dev/null || true)
            network=$(printf '%s' "$status_json" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
            catching_up=$(printf '%s' "$status_json" | jq -r 'if .result.sync_info.catching_up == null then empty else (.result.sync_info.catching_up | tostring) end' 2>/dev/null || true)
            if [ "$network" = "onyx-1" ] && [ "$catching_up" = "false" ]; then
                return 0
            fi
        fi
        sleep 1
    done

    echo "Post-start validation failed: Onyx RPC did not become synced and healthy within 120 seconds." >&2
    return 1
}

safe_stop_preflight() {
    local service_state rpc_base status_json network catching_up

    validate_service_target || return 1

    service_state=$(systemctl is-active "$GNOLAND_TESTNET_SERVICE_NAME" 2>/dev/null || true)
    case "$service_state" in
        inactive|failed)
            return 0
            ;;
        active)
            ;;
        *)
            echo "Safe-stop preflight blocked: unable to verify $GNOLAND_TESTNET_SERVICE_NAME.service state (reported: ${service_state:-unavailable})." >&2
            return 1
            ;;
    esac

    rpc_base=${GNOLAND_REMOTE:-$(get_local_rpc_url)}
    rpc_base=${rpc_base%/}
    case "$rpc_base" in
        http://127.0.0.1:*|http://localhost:*) ;;
        *)
            echo "Safe-stop preflight blocked: the Onyx status check must use a local loopback RPC endpoint." >&2
            return 1
            ;;
    esac

    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        echo "Safe-stop preflight blocked: curl and jq are required to verify node sync state." >&2
        return 1
    fi

    status_json=$(curl -m 5 -fsS "${rpc_base}/status" 2>/dev/null || true)
    network=$(printf '%s' "$status_json" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
    catching_up=$(printf '%s' "$status_json" | jq -r 'if .result.sync_info.catching_up == null then empty else (.result.sync_info.catching_up | tostring) end' 2>/dev/null || true)

    if [ "$network" != "onyx-1" ]; then
        echo "Safe-stop preflight blocked: local RPC did not verify onyx-1 (reported: ${network:-unavailable})." >&2
        return 1
    fi

    case "$catching_up" in
        false)
            return 0
            ;;
        true)
            echo "Safe-stop preflight blocked: this Onyx node reports catching_up=true." >&2
            echo "The pinned Onyx release predates gnolang/gno#6085; do not stop it while it is catching up." >&2
            return 1
            ;;
        *)
            echo "Safe-stop preflight blocked: local RPC did not return a recognised catching_up value." >&2
            return 1
            ;;
    esac
}

# Refuse obviously unsafe maintenance before doing network work.
safe_stop_preflight

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    echo "Update blocked: curl and jq are required for staged and post-start validation." >&2
    exit 1
fi
if [ -n "$(git -C "$GNO_SOURCE_DIR" status --porcelain)" ]; then
    echo "Update blocked: Gno source checkout has local changes; preserve them before updating." >&2
    exit 1
fi
PREVIOUS_SOURCE_COMMIT=$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)
if [ ! -f "$GNOLAND_BIN" ] || [ ! -f "$GNOKEY_BIN" ]; then
    echo "Update blocked: existing gnoland and gnokey binaries are required for rollback." >&2
    exit 1
fi

tmpdir=$(mktemp -d)
PREVIOUS_GNOLAND_BACKUP="$tmpdir/previous-gnoland"
PREVIOUS_GNOKEY_BACKUP="$tmpdir/previous-gnokey"
cp -p "$GNOLAND_BIN" "$PREVIOUS_GNOLAND_BACKUP"
cp -p "$GNOKEY_BIN" "$PREVIOUS_GNOKEY_BACKUP"

restore_previous_state() {
    local restore_failed=0
    if ! git -C "$GNO_SOURCE_DIR" checkout --detach --force "$PREVIOUS_SOURCE_COMMIT"; then
        restore_failed=1
    fi
    if ! cp -p "$PREVIOUS_GNOLAND_BACKUP" "$GNOLAND_BIN"; then
        restore_failed=1
    fi
    if ! cp -p "$PREVIOUS_GNOKEY_BACKUP" "$GNOKEY_BIN"; then
        restore_failed=1
    fi
    return "$restore_failed"
}

cleanup_and_recover() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "$ACTIVATION_ATTEMPTED" -eq 1 ] && [ "$ACTIVATION_SUCCEEDED" -eq 0 ]; then
        echo "Update activation failed; restoring the previous source and binaries." >&2
        if restore_previous_state; then
            if [ "$SERVICE_WAS_ACTIVE" -eq 1 ]; then
                if sudo systemctl restart "$GNOLAND_TESTNET_SERVICE_NAME"; then
                    echo "Recovery restart requested for ${GNOLAND_TESTNET_SERVICE_NAME}.service." >&2
                else
                    echo "Recovery restart failed; inspect ${GNOLAND_TESTNET_SERVICE_NAME}.service manually." >&2
                fi
            else
                sudo systemctl stop "$GNOLAND_TESTNET_SERVICE_NAME" || true
            fi
        else
            echo "Recovery restore failed; inspect ${GNOLAND_TESTNET_SERVICE_NAME}.service and source checkout manually." >&2
        fi
    fi
    rm -rf "$tmpdir"
    trap - EXIT
    exit "$exit_code"
}
trap cleanup_and_recover EXIT

# Stage and verify every network-dependent artifact while the node is still
# running. A GitHub/release outage or checksum failure must not create downtime.
if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    echo "Gno source checkout is missing at $GNO_SOURCE_DIR; run the Onyx installer instead." >&2
    exit 1
fi
if git -C "$GNO_SOURCE_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$GNO_SOURCE_DIR" remote set-url origin https://github.com/gnolang/gno.git
else
    git -C "$GNO_SOURCE_DIR" remote add origin https://github.com/gnolang/gno.git
fi
git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "$RELEASE_COMMIT"
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse FETCH_HEAD)" != "$RELEASE_COMMIT" ]; then
    echo "Fetched Gno source does not match the pinned Onyx commit." >&2
    exit 1
fi
verify_binary_release_metadata

curl -fsSL "https://github.com/gnolang/gno/releases/download/${BINARY_RELEASE_TAG}/gnoland_linux_amd64" -o "$tmpdir/gnoland"
curl -fsSL "https://github.com/gnolang/gno/releases/download/${BINARY_RELEASE_TAG}/gnokey_linux_amd64" -o "$tmpdir/gnokey"
echo "${GNOLAND_SHA256}  $tmpdir/gnoland" | sha256sum -c -
echo "${GNOKEY_SHA256}  $tmpdir/gnokey" | sha256sum -c -
chmod +x "$tmpdir/gnoland" "$tmpdir/gnokey"
verify_staged_binary_versions "$tmpdir/gnoland" "$tmpdir/gnokey"

# Sync state may have changed while artifacts were staged, so re-check immediately
# before crossing the maintenance boundary.
safe_stop_preflight
if systemctl is-active --quiet "$GNOLAND_TESTNET_SERVICE_NAME"; then
    SERVICE_WAS_ACTIVE=1
    sudo systemctl stop "$GNOLAND_TESTNET_SERVICE_NAME"
fi

# Everything below is local activation. No source fetch or release download should
# extend the stopped window.
mkdir -p "$HOME/go/bin"
git -C "$GNO_SOURCE_DIR" checkout --detach --force FETCH_HEAD
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" != "$RELEASE_COMMIT" ]; then
    echo "Unexpected Gno source commit at $GNO_SOURCE_DIR." >&2
    exit 1
fi
if [ ! -d "$GNO_SOURCE_DIR/gnovm/stdlibs/errors" ]; then
    echo "Missing Onyx stdlibs at $GNO_SOURCE_DIR/gnovm/stdlibs." >&2
    exit 1
fi

install "$tmpdir/gnoland" "$GNOLAND_BIN"
install "$tmpdir/gnokey" "$GNOKEY_BIN"

if [ ! -x "$GNOLAND_BIN" ] || [ ! -x "$GNOKEY_BIN" ]; then
    echo "Per-user Gnoland binaries are missing or not executable." >&2
    exit 1
fi

sed -i '/^export GNO_SOURCE_DIR=/d;/^export GNOROOT=/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true
{
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    echo 'export PATH="$HOME/go/bin:$PATH"'
} >> "$HOME/.bash_profile"

export PATH="$HOME/go/bin:$PATH"
hash -r
if [ "$(command -v gnoland)" != "$GNOLAND_BIN" ] || [ "$(command -v gnokey)" != "$GNOKEY_BIN" ]; then
    echo "Per-user commands do not resolve to $HOME/go/bin." >&2
    exit 1
fi

ACTIVATION_ATTEMPTED=1
sudo systemctl daemon-reload
sudo systemctl restart "$GNOLAND_TESTNET_SERVICE_NAME"
post_start_health_check
ACTIVATION_SUCCEEDED=1
sudo systemctl status "$GNOLAND_TESTNET_SERVICE_NAME" --no-pager -l || true
