#!/bin/bash

set -euo pipefail

GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
GNOLAND_SHA256="050f26c8dbff628a917dfae124b91696c1b25a26eddb645edb847e497b229ab9"
GNOKEY_SHA256="eece8675dfad4ce9801a57aa6b0284b278272f41e0aac4579c219bc30049a4de"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || true

curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/test13/gnoland_linux_amd64" -o "$tmpdir/gnoland"
curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/test13/gnokey_linux_amd64" -o "$tmpdir/gnokey"
echo "${GNOLAND_SHA256}  $tmpdir/gnoland" | sha256sum -c -
echo "${GNOKEY_SHA256}  $tmpdir/gnokey" | sha256sum -c -
chmod +x "$tmpdir/gnoland" "$tmpdir/gnokey"

sudo install "$tmpdir/gnoland" /usr/local/bin/gnoland
sudo install "$tmpdir/gnokey" /usr/local/bin/gnokey

sudo systemctl daemon-reload
sudo systemctl restart "$GNOLAND_SERVICE_NAME"
sudo systemctl status "$GNOLAND_SERVICE_NAME" --no-pager -l || true
