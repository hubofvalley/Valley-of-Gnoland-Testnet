#!/bin/bash

set -euo pipefail

GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
RELEASE_TAG="chain/topaz"
RELEASE_COMMIT="fc40526511474e40b8a66419f5ba28255085bc08"
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
GNOLAND_SHA256="e74ab25e366668c8c6774e3e8b23dd48288cf23a499a085c101cbbfca2a5f9c3"
GNOKEY_SHA256="660f5047c5fb4cd5768f0169f1140e95379996df421cbddf0e5e2602f1050438"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
mkdir -p "$HOME/go/bin"

if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    rm -rf "$GNO_SOURCE_DIR"
    git clone --depth 1 --branch "$RELEASE_TAG" https://github.com/gnolang/gno.git "$GNO_SOURCE_DIR"
else
    git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "$RELEASE_TAG"
    git -C "$GNO_SOURCE_DIR" checkout -f FETCH_HEAD
fi
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
sudo rm -f /usr/local/bin/gnoland /usr/local/bin/gnokey

sed -i '/^export GNO_SOURCE_DIR=/d;/^export GNOROOT=/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true
{
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    # shellcheck disable=SC2016
    echo 'export PATH="$HOME/go/bin:$PATH"'
} >> "$HOME/.bash_profile"

sudo systemctl daemon-reload
sudo systemctl restart "$GNOLAND_SERVICE_NAME"
sudo systemctl status "$GNOLAND_SERVICE_NAME" --no-pager -l || true
