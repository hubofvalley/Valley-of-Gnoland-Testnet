#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

CHAIN_ID="test-13"
RELEASE_TAG="chain/test13"
RELEASE_COMMIT="75c4bdf0598e7d7732c7f5d6fdd7ea4a03a3bd28"
GENESIS_URL="https://github.com/gnolang/gno/releases/download/chain/test13/genesis.json"
GENESIS_SHA256="56f56e135174feff9f93283d5ec7e4ec955cd5155108aff5009d4fd51c5adaf2"
GNOLAND_SHA256="050f26c8dbff628a917dfae124b91696c1b25a26eddb645edb847e497b229ab9"
GNOKEY_SHA256="eece8675dfad4ce9801a57aa6b0284b278272f41e0aac4579c219bc30049a4de"
SENTRY_PEERS="g142k7zc2qym3c0u6jmkf6rv26llgr2f4nakmlmt@sentry-1.test13.testnets.gno.land:26656,g1lxkf9gn7kddrr26c640ww5wg3ezsm22we8cjpc@sentry-2.test13.testnets.gno.land:26656"

echo -e "\n--- Gno.land Test13 Node Setup ---"

read -r -p "Enter your GNOLAND_MONIKER: " GNOLAND_MONIKER
if [ -z "$GNOLAND_MONIKER" ]; then
    echo -e "${RED}Moniker is required.${RESET}"
    exit 1
fi

read -r -p "Enter preferred port prefix (leave empty for default 26): " GNOLAND_PORT
GNOLAND_PORT=${GNOLAND_PORT:-26}
if ! [[ "$GNOLAND_PORT" =~ ^[0-9]{2}$ ]]; then
    echo -e "${RED}Port prefix must be two digits, for example 26 or 36.${RESET}"
    exit 1
fi

read -r -p "Enter public external address host/IP for P2P (optional, example 1.2.3.4): " GNOLAND_EXTERNAL_HOST
read -r -p "Install method - prebuilt binary or build from source? (p/s, default p): " INSTALL_METHOD
INSTALL_METHOD=${INSTALL_METHOD:-p}
read -r -p "Configure UFW firewall rules for Gnoland? (y/n, default n): " SETUP_UFW
SETUP_UFW=${SETUP_UFW:-n}

if [ -z "${GNOLAND_SERVICE_NAME:-}" ]; then
    read -r -p "Enter service name (default 'gnoland'): " GNOLAND_SERVICE_NAME
    GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
fi

GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
if [ -z "${GNOLAND_HOME:-}" ] || [ "$GNOLAND_HOME" = "$HOME/.gnoland" ]; then
    GNOLAND_HOME="$HOME/gnoland-data"
fi
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
if [ "$GNO_SOURCE_DIR" = "$HOME/gno-src-test13" ]; then
    GNO_SOURCE_DIR="$HOME/gno"
fi
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
if [ "$GNOROOT" = "$HOME/gno-src-test13" ]; then
    GNOROOT="$GNO_SOURCE_DIR"
fi
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
GNOLAND_RPC_PORT="${GNOLAND_PORT}657"
GNOLAND_P2P_PORT="${GNOLAND_PORT}656"

echo -e "${YELLOW}This is a clean deploy. Existing ${GNOLAND_SERVICE_NAME}.service and $GNOLAND_HOME will be removed.${RESET}"
echo -e "${RED}Backup node secrets before re-running on an existing validator identity.${RESET}"
read -r -p "Proceed with clean installation? (yes/no): " CONFIRM
if [[ "${CONFIRM,,}" != "yes" ]]; then
    echo "Installation cancelled."
    exit 0
fi

sudo systemctl daemon-reload
sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
sudo systemctl disable "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
sudo rm -f "/etc/systemd/system/${GNOLAND_SERVICE_NAME}.service"
sudo rm -f /usr/local/bin/gnoland /usr/local/bin/gnokey
rm -rf "$GNOLAND_HOME"
sed -i '/GNOLAND_/d;/GNOKEY_/d;/GNO_SOURCE_DIR/d;/GNOROOT/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true

sudo apt update -y
sudo apt install -y curl git jq build-essential make gcc wget ca-certificates
mkdir -p "$HOME/go/bin"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo -e "${CYAN}Preparing Gno source tree for Test13 stdlibs.${RESET}"
if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
    rm -rf "$GNO_SOURCE_DIR"
    git clone --depth 1 --branch "$RELEASE_TAG" https://github.com/gnolang/gno.git "$GNO_SOURCE_DIR"
else
    git -C "$GNO_SOURCE_DIR" fetch --depth 1 origin "$RELEASE_TAG"
    git -C "$GNO_SOURCE_DIR" checkout -f FETCH_HEAD
fi
if [ "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" != "$RELEASE_COMMIT" ]; then
    echo -e "${RED}Unexpected Gno source commit at $GNO_SOURCE_DIR.${RESET}"
    exit 1
fi
if [ ! -d "$GNO_SOURCE_DIR/gnovm/stdlibs/errors" ]; then
    echo -e "${RED}Missing Test13 stdlibs at $GNO_SOURCE_DIR/gnovm/stdlibs.${RESET}"
    exit 1
fi

if [[ "$INSTALL_METHOD" =~ ^[Ss]$ ]]; then
    echo -e "${CYAN}Building gnoland and gnokey from source branch ${RELEASE_TAG}.${RESET}"
    cd "$GNO_SOURCE_DIR"
    make -C gno.land install.gnoland install.gnokey
else
    echo -e "${CYAN}Downloading official Test13 release binaries.${RESET}"
    curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/test13/gnoland_linux_amd64" -o "$tmpdir/gnoland"
    curl -fsSL "https://github.com/gnolang/gno/releases/download/chain/test13/gnokey_linux_amd64" -o "$tmpdir/gnokey"
    echo "${GNOLAND_SHA256}  $tmpdir/gnoland" | sha256sum -c -
    echo "${GNOKEY_SHA256}  $tmpdir/gnokey" | sha256sum -c -
    chmod +x "$tmpdir/gnoland" "$tmpdir/gnokey"
    install "$tmpdir/gnoland" "$GNOLAND_BIN"
    install "$tmpdir/gnokey" "$GNOKEY_BIN"
fi

export GNOROOT
export PATH="$HOME/go/bin:$PATH"
"$GNOLAND_BIN" version || true
"$GNOKEY_BIN" version || true

mkdir -p "$GNOLAND_HOME/config" "$GNOLAND_HOME/secrets" "$GNOKEY_HOME"

cd "$GNOLAND_HOME"
"$GNOLAND_BIN" config init -config-path "$GNOLAND_HOME/config/config.toml" -force
"$GNOLAND_BIN" secrets init -data-dir "$GNOLAND_HOME/secrets" -force

curl -fsSL "$GENESIS_URL" -o "$GNOLAND_HOME/genesis.json"
echo "${GENESIS_SHA256}  $GNOLAND_HOME/genesis.json" | sha256sum -c -

"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" moniker "$GNOLAND_MONIKER"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" p2p.laddr "tcp://0.0.0.0:${GNOLAND_P2P_PORT}"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" rpc.laddr "tcp://127.0.0.1:${GNOLAND_RPC_PORT}"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" p2p.persistent_peers "$SENTRY_PEERS"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" application.prune_strategy "syncable"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" consensus.timeout_commit "3s"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" consensus.peer_gossip_sleep_duration "10ms"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" p2p.flush_throttle_timeout "10ms"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" p2p.pex "true"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" mempool.size "10000"
"$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" p2p.max_num_outbound_peers "40"

if [ -n "$GNOLAND_EXTERNAL_HOST" ]; then
    "$GNOLAND_BIN" config set -config-path "$GNOLAND_HOME/config/config.toml" p2p.external_address "${GNOLAND_EXTERNAL_HOST}:${GNOLAND_P2P_PORT}"
fi

if [[ "$SETUP_UFW" =~ ^[Yy]$ ]]; then
    sudo apt install -y ufw
    sudo ufw allow 22/tcp comment "SSH Access"
    sudo ufw allow "${GNOLAND_P2P_PORT}/tcp" comment "Gno.land Test13 P2P"
    sudo ufw --force enable
    sudo ufw status verbose
fi

sudo tee "/etc/systemd/system/${GNOLAND_SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=Gno.land Test13 Node (${GNOLAND_SERVICE_NAME})
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$GNOLAND_HOME
Environment=GNOROOT=$GNOROOT
Environment=PATH=$HOME/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=$GNOLAND_BIN start -chainid $CHAIN_ID -gnoroot-dir $GNOROOT -data-dir $GNOLAND_HOME -genesis $GNOLAND_HOME/genesis.json -skip-genesis-sig-verification
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF

{
    echo "export GNOLAND_MONIKER=\"$GNOLAND_MONIKER\""
    echo "export GNOLAND_CHAIN_ID=\"$CHAIN_ID\""
    echo "export GNOLAND_PORT=\"$GNOLAND_PORT\""
    echo "export GNOLAND_HOME=\"$GNOLAND_HOME\""
    echo "export GNOKEY_HOME=\"$GNOKEY_HOME\""
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    echo 'export PATH="$HOME/go/bin:$PATH"'
    echo "export GNOLAND_SERVICE_NAME=\"$GNOLAND_SERVICE_NAME\""
    echo "export GNOLAND_REMOTE=\"http://127.0.0.1:${GNOLAND_RPC_PORT}\""
    echo "export GNOLAND_PUBLIC_REMOTE=\"https://rpc.test13.testnets.gno.land\""
} >> "$HOME/.bash_profile"

sudo systemctl daemon-reload
sudo systemctl enable "$GNOLAND_SERVICE_NAME"
sudo systemctl restart "$GNOLAND_SERVICE_NAME"

if systemctl is-active --quiet "$GNOLAND_SERVICE_NAME"; then
    echo -e "${GREEN}Gnoland service started successfully.${RESET}"
    echo "Local status: curl -s http://127.0.0.1:${GNOLAND_RPC_PORT}/status | jq '.result.sync_info'"
    echo "Reload shell env before using gnoland manually in this terminal:"
    echo "source ~/.bash_profile && hash -r"
else
    echo -e "${RED}Gnoland service did not start. Check logs:${RESET}"
    echo "sudo journalctl -u ${GNOLAND_SERVICE_NAME} -n 100 --no-pager"
    exit 1
fi

echo "Let's Buidl Gnoland Together"
