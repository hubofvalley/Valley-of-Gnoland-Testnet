# Gno.land Sapphire Node - Manual Guide

Official validator source:

- https://github.com/gnolang/gno/blob/chain/sapphire/misc/deployments/sapphire.gno.land/VALIDATOR.md
- https://github.com/gnolang/gno/releases/tag/chain/sapphire

## Network facts

| Field | Value |
|---|---|
| Chain ID | `sapphire-1` |
| RPC | `https://rpc.sapphire.testnets.gno.land` |
| Faucet | `https://sapphire.testnets.gno.land/faucet` |
| Release commit | `9ab5198acac68016341655c82290ecaff5591edb` |
| Genesis SHA256 | `d511e0e5b767d4e53f5c1afeeea1bc61d2c7b2118146c820f1f3e4296f67498e` |

Official persistent peers:

```text
g10xll77gz6yzg43v9mdalj8360ng6sunt2vvvhf@seed-1.sapphire.testnets.gno.land:26656,g1gw2d7qsmrg06p204ty2qs8ygzd32t2c7p46te0@seed-2.sapphire.testnets.gno.land:26656
```

## Existing directory layout

```bash
GNO_SOURCE_DIR="$HOME/gno"
GNOLAND_HOME="$HOME/gno/gnoland-data"
GNOKEY_HOME="$HOME/.config/gno"
GNOLAND_BIN="$HOME/go/bin/gnoland"
GNOKEY_BIN="$HOME/go/bin/gnokey"
```

Run installation as the OS user that owns these paths. For multiple nodes on one server, use a different OS user, service name, and port prefix for each instance. Do not create a shared `/usr/local/bin/gnoland` symlink; systemd should execute the per-user binary by absolute path.

Sapphire replaces Topaz chain data in `GNOLAND_HOME`. Back up node secrets and the operator keyring first. Preserve `GNOKEY_HOME` if reusing the Topaz operator address.

```bash
BACKUP_DIR="$HOME/gnoland-migration-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/topaz-node-secrets.tar.gz" -C "$HOME/gno/gnoland-data" secrets
tar -czf "$BACKUP_DIR/operator-keyring.tar.gz" -C "$HOME/.config" gno
chmod 600 "$BACKUP_DIR"/*.tar.gz
```

## Install pinned binaries and source

```bash
git -C "$HOME/gno" remote set-url origin https://github.com/gnolang/gno.git
git -C "$HOME/gno" fetch --depth 1 origin 9ab5198acac68016341655c82290ecaff5591edb
git -C "$HOME/gno" checkout --detach --force FETCH_HEAD
test "$(git -C "$HOME/gno" rev-parse HEAD)" = "9ab5198acac68016341655c82290ecaff5591edb"

curl -fsSLO https://github.com/gnolang/gno/releases/download/chain/sapphire/gnoland_linux_amd64
curl -fsSLO https://github.com/gnolang/gno/releases/download/chain/sapphire/gnokey_linux_amd64
echo "b77b033df80a10bd97d836a2c3eb2b4257279cd7240f21ed6e06b67c7306a434  gnoland_linux_amd64" | sha256sum -c -
echo "f27c7ad0430bdc4a7855af6a6762d202b7d609161f80a8fa223f85882bef486d  gnokey_linux_amd64" | sha256sum -c -
install gnoland_linux_amd64 "$HOME/go/bin/gnoland"
install gnokey_linux_amd64 "$HOME/go/bin/gnokey"
export PATH="$HOME/go/bin:$PATH"
hash -r
test "$(command -v gnoland)" = "$HOME/go/bin/gnoland"
test "$(command -v gnokey)" = "$HOME/go/bin/gnokey"
```

## Operator key

Existing validators should list and reuse the Topaz key:

```bash
gnokey -home "$HOME/.config/gno" list
```

If the keyring is unavailable, recover the same Topaz mnemonic:

```bash
gnokey -home "$HOME/.config/gno" add -recover operator
```

Do not create a new operator key if the goal is migration of an existing Topaz validator.

## Initialise Sapphire

```bash
export GNOROOT="$HOME/gno"
cd "$HOME/gno"
rm -rf "$HOME/gno/gnoland-data"
gnoland config init -force
gnoland secrets init -force
curl -fsSL https://github.com/gnolang/gno/releases/download/chain/sapphire/genesis.json -o genesis.json
echo "d511e0e5b767d4e53f5c1afeeea1bc61d2c7b2118146c820f1f3e4296f67498e  genesis.json" | sha256sum -c -
```

`gnoland secrets init` creates a fresh Sapphire consensus key. It does not alter the operator keyring.

## Configure and start

```bash
PERSISTENT_PEERS="g10xll77gz6yzg43v9mdalj8360ng6sunt2vvvhf@seed-1.sapphire.testnets.gno.land:26656,g1gw2d7qsmrg06p204ty2qs8ygzd32t2c7p46te0@seed-2.sapphire.testnets.gno.land:26656"
PORT_PREFIX="26"
EXTERNAL_HOST="your-public-host-or-ip"

gnoland config set moniker "your-moniker"
gnoland config set proxy_app "tcp://127.0.0.1:${PORT_PREFIX}658"
gnoland config set p2p.laddr "tcp://0.0.0.0:${PORT_PREFIX}656"
gnoland config set rpc.laddr "tcp://127.0.0.1:${PORT_PREFIX}657"
gnoland config set p2p.seeds ""
gnoland config set p2p.persistent_peers "$PERSISTENT_PEERS"
gnoland config set p2p.external_address "${EXTERNAL_HOST}:${PORT_PREFIX}656"
gnoland config set application.prune_strategy syncable
gnoland config set consensus.timeout_commit 3s
gnoland config set consensus.peer_gossip_sleep_duration 10ms
gnoland config set p2p.flush_throttle_timeout 10ms
gnoland config set p2p.pex true
gnoland config set mempool.size 10000
gnoland config set p2p.max_num_outbound_peers 40

gnoland start \
  --chainid sapphire-1 \
  --genesis genesis.json \
  --skip-genesis-sig-verification \
  --log-level info
```

The selected two-digit prefix must be `01`–`64` so every generated TCP port remains valid. It applies to every local Gnoland listener: ABCI `${PORT_PREFIX}658`, P2P `${PORT_PREFIX}656`, and RPC `${PORT_PREFIX}657`. The two official peer addresses remain on their published remote port `26656`.

Sapphire does not consume `p2p.seeds`; the official bootstrap nodes must be configured in `p2p.persistent_peers`. `p2p.external_address` must advertise a host or public IP that other peers can dial.

## Register the valoper candidate

After sync, get the new consensus key:

```bash
cd "$HOME/gno"
gnoland secrets get validator_key
```

Register using the same operator key/address used on Topaz:

```bash
gnokey -home "$HOME/.config/gno" -remote https://rpc.sapphire.testnets.gno.land maketx call \
  -pkgpath gno.land/r/gnops/valopers \
  -func Register \
  -args "<moniker>" \
  -args "<description>" \
  -args "<cloud|on-prem|data-center>" \
  -args "<same Topaz operator g1... address>" \
  -args "<new Sapphire gpub1... consensus pubkey>" \
  -gas-fee 1000000ugnot \
  -gas-wanted 100000000 \
  -chainid sapphire-1 \
  -broadcast \
  operator
```

Registration creates a candidate profile. GovDAO must pass the active-validator proposal.

last updated by: John
