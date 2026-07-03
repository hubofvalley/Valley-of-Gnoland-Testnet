# Gno.land Test13 Node - Manual Guide

Manual command summary behind the `valleyofGnoland.sh` menu. Sources:

- https://docs.gno.land/resources/gnoland-networks/
- https://github.com/gnolang/gno/releases/tag/chain/test13
- https://raw.githubusercontent.com/gnolang/gno/chain/test13/misc/deployments/test13.gno.land/VALIDATOR.md

## Network facts

| Field | Value |
|---|---|
| Network | Gno.land Test13 |
| Chain ID | `test-13` |
| RPC | `https://rpc.test13.testnets.gno.land` |
| Faucet | `https://test13.testnets.gno.land/faucet` |
| Genesis SHA256 | `56f56e135174feff9f93283d5ec7e4ec955cd5155108aff5009d4fd51c5adaf2` |

Official sentry peers:

```text
g142k7zc2qym3c0u6jmkf6rv26llgr2f4nakmlmt@sentry-1.test13.testnets.gno.land:26656,g1lxkf9gn7kddrr26c640ww5wg3ezsm22we8cjpc@sentry-2.test13.testnets.gno.land:26656
```

## Install binaries

Prebuilt:

```bash
curl -fsSLO https://github.com/gnolang/gno/releases/download/chain/test13/gnoland_linux_amd64
curl -fsSLO https://github.com/gnolang/gno/releases/download/chain/test13/gnokey_linux_amd64
echo "050f26c8dbff628a917dfae124b91696c1b25a26eddb645edb847e497b229ab9  gnoland_linux_amd64" | sha256sum -c -
echo "eece8675dfad4ce9801a57aa6b0284b278272f41e0aac4579c219bc30049a4de  gnokey_linux_amd64" | sha256sum -c -
chmod +x gnoland_linux_amd64 gnokey_linux_amd64
sudo install gnoland_linux_amd64 /usr/local/bin/gnoland
sudo install gnokey_linux_amd64 /usr/local/bin/gnokey
```

Build from source:

```bash
git clone https://github.com/gnolang/gno.git
cd gno
git checkout chain/test13
make -C gno.land install.gnoland install.gnokey
sudo install "$HOME/go/bin/gnoland" /usr/local/bin/gnoland
sudo install "$HOME/go/bin/gnokey" /usr/local/bin/gnokey
```

## Prepare Test13 stdlibs

`gnoland` loads standard libraries from the Gno source tree at runtime. Keep the source tree pinned to the Test13 release branch and pass it with `-gnoroot-dir`.

```bash
GNO_SOURCE_DIR="$HOME/gno-src-test13"
git clone --depth 1 --branch chain/test13 https://github.com/gnolang/gno.git "$GNO_SOURCE_DIR"
test "$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD)" = "75c4bdf0598e7d7732c7f5d6fdd7ea4a03a3bd28"
test -d "$GNO_SOURCE_DIR/gnovm/stdlibs/errors"
```

## Init config, secrets, and genesis

```bash
GNOLAND_HOME="$HOME/.gnoland"
mkdir -p "$GNOLAND_HOME/config" "$GNOLAND_HOME/secrets"

gnoland config init -config-path "$GNOLAND_HOME/config/config.toml" -force
gnoland secrets init -data-dir "$GNOLAND_HOME/secrets" -force

curl -fsSL https://github.com/gnolang/gno/releases/download/chain/test13/genesis.json -o "$GNOLAND_HOME/genesis.json"
echo "56f56e135174feff9f93283d5ec7e4ec955cd5155108aff5009d4fd51c5adaf2  $GNOLAND_HOME/genesis.json" | sha256sum -c -
```

## Configure node

```bash
CFG="$GNOLAND_HOME/config/config.toml"
MONIKER="your-moniker"
P2P_PORT="26656"
RPC_PORT="26657"
PEERS="g142k7zc2qym3c0u6jmkf6rv26llgr2f4nakmlmt@sentry-1.test13.testnets.gno.land:26656,g1lxkf9gn7kddrr26c640ww5wg3ezsm22we8cjpc@sentry-2.test13.testnets.gno.land:26656"

gnoland config set -config-path "$CFG" moniker "$MONIKER"
gnoland config set -config-path "$CFG" p2p.laddr "tcp://0.0.0.0:${P2P_PORT}"
gnoland config set -config-path "$CFG" rpc.laddr "tcp://127.0.0.1:${RPC_PORT}"
gnoland config set -config-path "$CFG" p2p.persistent_peers "$PEERS"
gnoland config set -config-path "$CFG" application.prune_strategy "syncable"
gnoland config set -config-path "$CFG" consensus.timeout_commit "3s"
gnoland config set -config-path "$CFG" consensus.peer_gossip_sleep_duration "10ms"
gnoland config set -config-path "$CFG" p2p.flush_throttle_timeout "10ms"
gnoland config set -config-path "$CFG" p2p.pex "true"
gnoland config set -config-path "$CFG" mempool.size "10000"
gnoland config set -config-path "$CFG" p2p.max_num_outbound_peers "40"
```

Set `p2p.external_address` if peers need to dial your public host:

```bash
gnoland config set -config-path "$CFG" p2p.external_address "YOUR_PUBLIC_HOST:${P2P_PORT}"
```

## Start manually

```bash
gnoland start \
  -chainid test-13 \
  -gnoroot-dir "$GNO_SOURCE_DIR" \
  -data-dir "$GNOLAND_HOME" \
  -genesis "$GNOLAND_HOME/genesis.json" \
  -skip-genesis-sig-verification
```

`-skip-genesis-sig-verification` is required by upstream Test13 docs because the genesis replays historical transactions whose signatures a fresh node cannot all re-verify.

Check status:

```bash
curl -s http://127.0.0.1:26657/status | jq '.result.sync_info'
curl -s https://rpc.test13.testnets.gno.land/status | jq '.result.sync_info.latest_block_height'
```

## Systemd service

```ini
[Unit]
Description=Gno.land Test13 Node
After=network-online.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/.gnoland
ExecStart=/usr/local/bin/gnoland start -chainid test-13 -gnoroot-dir /home/ubuntu/gno-src-test13 -data-dir /home/ubuntu/.gnoland -genesis /home/ubuntu/.gnoland/genesis.json -skip-genesis-sig-verification
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
```

Adjust `User` and paths for your server user.

## Operator key and valoper candidate registration

Create or recover a burner/testnet-only operator key:

```bash
GNOKEY_HOME="$HOME/.config/gno"
gnokey -home "$GNOKEY_HOME" add operator
# or:
gnokey -home "$GNOKEY_HOME" add -recover operator
```

Fund the `g1...` operator address from:

```text
https://test13.testnets.gno.land/faucet
```

Get the node consensus public key:

```bash
gnoland secrets get -data-dir "$GNOLAND_HOME/secrets" validator_key
```

Register candidate:

```bash
gnokey -home "$GNOKEY_HOME" -remote https://rpc.test13.testnets.gno.land maketx call \
  -pkgpath gno.land/r/gnops/valopers \
  -func Register \
  -args "<moniker>" \
  -args "<description>" \
  -args "<cloud|on-prem|data-center>" \
  -args "<your operator g1... address>" \
  -args "<your gpub1... consensus pubkey>" \
  -gas-fee 1000000ugnot \
  -gas-wanted 50000000 \
  -chainid test-13 \
  -broadcast \
  operator
```

Registration only lists the operator as a candidate. A GovDAO member must create and pass a proposal via `r/sys/validators/v3` before active validator admission.
