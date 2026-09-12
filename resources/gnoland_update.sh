#!/bin/bash

set -euo pipefail

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

readonly RELEASE_COMMIT="c4c72fdd288c757e8da0d93aae867fa479b1b15c"
readonly GNOLAND_SHA256="055b24001a31de7054649a049c9f9db5282965713814b84f7f864e8e6efa237d"
readonly GNOKEY_SHA256="a69017c6e9ce9d77d3bd2f1e811731f6353e0deba5da4f620672d58e5fcec804"
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
GNOLAND_REMOTE=${GNOLAND_REMOTE:-http://127.0.0.1:26657}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
OS_USER=$(id -un)
SERVICE_FILE=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)

if [ -n "${SUDO_USER:-}" ]; then
    echo "Run the updater as the node OS user, not with sudo." >&2
    exit 1
fi

for instance_path in "$GNO_SOURCE_DIR" "$GNOLAND_BIN" "$GNOKEY_BIN"; do
    CANONICAL_HOME=$(realpath -m "$HOME")
    CANONICAL_PATH=$(realpath -m "$instance_path")
    case "$CANONICAL_PATH" in
        "$CANONICAL_HOME"/*) ;;
        *) echo "Unsafe instance path outside $HOME: $instance_path" >&2; exit 1 ;;
    esac
done

if [[ ! "$GNOLAND_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
    echo "Invalid Gnoland service name: $GNOLAND_SERVICE_NAME" >&2
    exit 1
fi

if [ -n "$SERVICE_FILE" ]; then
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Cannot inspect existing service: $SERVICE_FILE" >&2
        exit 1
    fi
    UNIT_USER=$(sed -n 's/^User=//p' "$SERVICE_FILE" | tail -n 1)
    UNIT_WORKDIR=$(sed -n 's/^WorkingDirectory=//p' "$SERVICE_FILE" | tail -n 1)
    if [ "$UNIT_USER" != "$OS_USER" ] || [ "$UNIT_WORKDIR" != "$GNO_SOURCE_DIR" ]; then
        echo "$GNOLAND_SERVICE_NAME.service belongs to another instance." >&2
        exit 1
    fi
    if ! grep -Fq -- '--chainid pearl-1' "$SERVICE_FILE"; then
        echo "Update blocked: this service is not configured for pearl-1." >&2
        echo "Use Deploy/Re-deploy to perform the Sapphire -> Pearl fresh-chain migration first." >&2
        exit 1
    fi
    if ! grep -Fq -- '--skip-genesis-sig-verification' "$SERVICE_FILE"; then
        echo "Update blocked: Pearl requires --skip-genesis-sig-verification in ExecStart." >&2
        exit 1
    fi
fi

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "The verified prebuilt updater currently supports Linux amd64 only." >&2
    exit 1
fi

function safe_stop_preflight() {
    local rpc_base status_json network catching_up

    if ! systemctl is-active --quiet "$GNOLAND_SERVICE_NAME"; then
        return 0
    fi

    rpc_base=${GNOLAND_REMOTE%/}
    case "$rpc_base" in
        http://127.0.0.1:*|http://localhost:*) ;;
        *)
            echo "Safe-stop preflight blocked: GNOLAND_REMOTE must point to a local loopback RPC endpoint." >&2
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

    if [ "$network" != "pearl-1" ]; then
        echo "Safe-stop preflight blocked: local RPC did not verify pearl-1 (reported: ${network:-unavailable})." >&2
        return 1
    fi

    case "$catching_up" in
        false)
            return 0
            ;;
        true)
            echo "Safe-stop preflight blocked: this Pearl node reports catching_up=true." >&2
            echo "Current Pearl predates gnolang/gno#6085; stopping while catching up can leave the local store unable to restart without recovery." >&2
            return 1
            ;;
        *)
            echo "Safe-stop preflight blocked: local RPC did not return a recognised catching_up value." >&2
            return 1
            ;;
    esac
}

# Refuse obviously unsafe maintenance before doing any updater work.
safe_stop_preflight

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Stage and verify every network-dependent artifact while the node is still
# running. A GitHub/release outage or checksum failure must not create downtime.
if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    echo "Gno source checkout is missing at $GNO_SOURCE_DIR; run the Pearl installer instead." >&2
    exit 1
fi
if git -C "$GNO_SOURCE_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$GNO_SOURCE_DIR" remote set-url origin https://github.com/gnolang/gno.git
else
    git -C "$GNO_SOURCE_DIR" remote add origin https://github.com/gnolang/gno.git
fi
git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "$RELEASE_COMMIT"
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse FETCH_HEAD)" != "$RELEASE_COMMIT" ]; then
    echo "Fetched Gno source does not match the pinned Pearl commit." >&2
    exit 1
fi

curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/pearl/gnoland_linux_amd64" -o "$tmpdir/gnoland"
curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/pearl/gnokey_linux_amd64" -o "$tmpdir/gnokey"
echo "${GNOLAND_SHA256}  $tmpdir/gnoland" | sha256sum -c -
echo "${GNOKEY_SHA256}  $tmpdir/gnokey" | sha256sum -c -
chmod +x "$tmpdir/gnoland" "$tmpdir/gnokey"

# Re-check immediately before the maintenance boundary in case sync state changed
# while artifacts were staged.
safe_stop_preflight
sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || true

# Everything below is local activation: no release download or source fetch should
# extend the node's stopped window.
mkdir -p "$HOME/go/bin"
git -C "$GNO_SOURCE_DIR" checkout --detach --force FETCH_HEAD
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" != "$RELEASE_COMMIT" ]; then
    echo "Unexpected Gno source commit at $GNO_SOURCE_DIR." >&2
    exit 1
fi
if [ ! -d "$GNO_SOURCE_DIR/gnovm/stdlibs/errors" ]; then
    echo "Missing Pearl stdlibs at $GNO_SOURCE_DIR/gnovm/stdlibs." >&2
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

sudo systemctl daemon-reload
sudo systemctl restart "$GNOLAND_SERVICE_NAME"
sudo systemctl status "$GNOLAND_SERVICE_NAME" --no-pager -l || true
