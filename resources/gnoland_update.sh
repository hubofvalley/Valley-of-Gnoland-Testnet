#!/bin/bash

set -euo pipefail

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
RELEASE_COMMIT="fc40526511474e40b8a66419f5ba28255085bc08"
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
GNOLAND_SHA256="e74ab25e366668c8c6774e3e8b23dd48288cf23a499a085c101cbbfca2a5f9c3"
GNOKEY_SHA256="660f5047c5fb4cd5768f0169f1140e95379996df421cbddf0e5e2602f1050438"
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
        *)
            echo "Unsafe instance path outside $HOME: $instance_path" >&2
            exit 1
            ;;
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
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
mkdir -p "$HOME/go/bin"

if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    rm -rf "$GNO_SOURCE_DIR"
    mkdir -p "$GNO_SOURCE_DIR"
    git -C "$GNO_SOURCE_DIR" init
fi
if git -C "$GNO_SOURCE_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$GNO_SOURCE_DIR" remote set-url origin https://github.com/gnolang/gno.git
else
    git -C "$GNO_SOURCE_DIR" remote add origin https://github.com/gnolang/gno.git
fi
git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "$RELEASE_COMMIT"
git -C "$GNO_SOURCE_DIR" checkout --detach --force FETCH_HEAD
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" != "$RELEASE_COMMIT" ]; then
    echo "Unexpected Gno source commit at $GNO_SOURCE_DIR."
    exit 1
fi
if [ ! -d "$GNO_SOURCE_DIR/gnovm/stdlibs/errors" ]; then
    echo "Missing Topaz stdlibs at $GNO_SOURCE_DIR/gnovm/stdlibs."
    exit 1
fi

curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/topaz/gnoland_linux_amd64" -o "$tmpdir/gnoland"
curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/topaz/gnokey_linux_amd64" -o "$tmpdir/gnokey"
echo "${GNOLAND_SHA256}  $tmpdir/gnoland" | sha256sum -c -
echo "${GNOKEY_SHA256}  $tmpdir/gnokey" | sha256sum -c -
chmod +x "$tmpdir/gnoland" "$tmpdir/gnokey"

install "$tmpdir/gnoland" "$GNOLAND_BIN"
install "$tmpdir/gnokey" "$GNOKEY_BIN"

if [ ! -x "$GNOLAND_BIN" ] || [ ! -x "$GNOKEY_BIN" ]; then
    echo "Per-user Gnoland binaries are missing or not executable."
    exit 1
fi

sed -i '/^export GNO_SOURCE_DIR=/d;/^export GNOROOT=/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true
{
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    # shellcheck disable=SC2016
    echo 'export PATH="$HOME/go/bin:$PATH"'
} >> "$HOME/.bash_profile"

export PATH="$HOME/go/bin:$PATH"
hash -r
if [ "$(command -v gnoland)" != "$GNOLAND_BIN" ] ||
   [ "$(command -v gnokey)" != "$GNOKEY_BIN" ]; then
    echo "Per-user commands do not resolve to $HOME/go/bin." >&2
    exit 1
fi

sudo systemctl daemon-reload
sudo systemctl restart "$GNOLAND_SERVICE_NAME"
sudo systemctl status "$GNOLAND_SERVICE_NAME" --no-pager -l || true
