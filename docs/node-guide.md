# Gno.land Topaz Node - Manual Guide

Official validator source:

- https://github.com/gnolang/gno/blob/chain/topaz/misc/deployments/topaz.gno.land/VALIDATOR.md
- https://github.com/gnolang/gno/releases/tag/chain/topaz

## Network facts

| Field | Value |
|---|---|
| Chain ID | `topaz-1` |
| RPC | `https://rpc.topaz.testnets.gno.land` |
| Faucet | `https://topaz.testnets.gno.land/faucet` |
| Release commit | `fc40526511474e40b8a66419f5ba28255085bc08` |
| Genesis SHA256 | `2dd049f973b82858727440df9aff5722cb0b322fd00890f40f2b0688276898ff` |

Official seeds:

```text
g19q07ssuafhmg6r7ys7wp7rpc4jxc85cpvdy426@seed-1.topaz.testnets.gno.land:26656,g15k98e65gm8h7fdr3yr4tqn82lvch4a97a3sg3j@seed-2.topaz.testnets.gno.land:26656
```

## Existing directory layout

```bash
GNO_SOURCE_DIR="$HOME/gno"
GNOLAND_HOME="$HOME/gno/gnoland-data"
GNOKEY_HOME="$HOME/.config/gno"
```

Topaz replaces Test13 chain data in `GNOLAND_HOME`. Back up node secrets and the operator keyring first. Preserve `GNOKEY_HOME` if reusing the Test13 operator address.

```bash
BACKUP_DIR="$HOME/gnoland-migration-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/test13-node-secrets.tar.gz" -C "$HOME/gno/gnoland-data" secrets
tar -czf "$BACKUP_DIR/operator-keyring.tar.gz" -C "$HOME/.config" gno
chmod 600 "$BACKUP_DIR"/*.tar.gz
```

## Install pinned binaries and source

```bash
git -C "$HOME/gno" remote set-url origin https://github.com/gnolang/gno.git
git -C "$HOME/gno" fetch --depth 1 origin fc40526511474e40b8a66419f5ba28255085bc08
git -C "$HOME/gno" checkout --detach --force FETCH_HEAD
test "$(git -C "$HOME/gno" rev-parse HEAD)" = "fc40526511474e40b8a66419f5ba28255085bc08"

curl -fsSLO https://github.com/gnolang/gno/releases/download/chain/topaz/gnoland_linux_amd64
curl -fsSLO https://github.com/gnolang/gno/releases/download/chain/topaz/gnokey_linux_amd64
echo "e74ab25e366668c8c6774e3e8b23dd48288cf23a499a085c101cbbfca2a5f9c3  gnoland_linux_amd64" | sha256sum -c -
echo "660f5047c5fb4cd5768f0169f1140e95379996df421cbddf0e5e2602f1050438  gnokey_linux_amd64" | sha256sum -c -
install gnoland_linux_amd64 "$HOME/go/bin/gnoland"
install gnokey_linux_amd64 "$HOME/go/bin/gnokey"
```

## Operator key

Existing validators should list and reuse the Test13 key:

```bash
gnokey -home "$HOME/.config/gno" list
```

If the keyring is unavailable, recover the same Test13 mnemonic:

```bash
gnokey -home "$HOME/.config/gno" add -recover operator
```

Do not create a new operator key if the goal is migration of an existing Test13 validator.

## Initialise Topaz

```bash
export GNOROOT="$HOME/gno"
cd "$HOME/gno"
rm -rf "$HOME/gno/gnoland-data"
gnoland config init -force
gnoland secrets init -force
curl -fsSL https://github.com/gnolang/gno/releases/download/chain/topaz/genesis.json -o genesis.json
echo "2dd049f973b82858727440df9aff5722cb0b322fd00890f40f2b0688276898ff  genesis.json" | sha256sum -c -
```

`gnoland secrets init` creates a fresh Topaz consensus key. It does not alter the operator keyring.

## Configure and start

```bash
SEEDS="g19q07ssuafhmg6r7ys7wp7rpc4jxc85cpvdy426@seed-1.topaz.testnets.gno.land:26656,g15k98e65gm8h7fdr3yr4tqn82lvch4a97a3sg3j@seed-2.topaz.testnets.gno.land:26656"
PORT_PREFIX="26"

gnoland config set moniker "your-moniker"
gnoland config set proxy_app "tcp://127.0.0.1:${PORT_PREFIX}658"
gnoland config set p2p.laddr "tcp://0.0.0.0:${PORT_PREFIX}656"
gnoland config set rpc.laddr "tcp://127.0.0.1:${PORT_PREFIX}657"
gnoland config set p2p.seeds "$SEEDS"
gnoland config set application.prune_strategy syncable
gnoland config set consensus.timeout_commit 3s
gnoland config set consensus.peer_gossip_sleep_duration 10ms
gnoland config set p2p.flush_throttle_timeout 10ms
gnoland config set p2p.pex true
gnoland config set mempool.size 10000
gnoland config set p2p.max_num_outbound_peers 40

gnoland start \
  -chainid topaz-1 \
  -genesis genesis.json \
  -skip-genesis-sig-verification \
  -log-level info
```

The selected two-digit prefix applies to every local Gnoland listener: ABCI `${PORT_PREFIX}658`, P2P `${PORT_PREFIX}656`, and RPC `${PORT_PREFIX}657`. Official seed addresses remain on their published remote port `26656`.

## Register the valoper candidate

After sync, get the new consensus key:

```bash
cd "$HOME/gno"
gnoland secrets get validator_key
```

Register using the same operator key/address used on Test13:

```bash
gnokey -home "$HOME/.config/gno" -remote https://rpc.topaz.testnets.gno.land maketx call \
  -pkgpath gno.land/r/gnops/valopers \
  -func Register \
  -args "<moniker>" \
  -args "<description>" \
  -args "<cloud|on-prem|data-center>" \
  -args "<same Test13 operator g1... address>" \
  -args "<new Topaz gpub1... consensus pubkey>" \
  -gas-fee 1000000ugnot \
  -gas-wanted 50000000 \
  -chainid topaz-1 \
  -broadcast \
  operator
```

Registration creates a candidate profile. GovDAO must pass the active-validator proposal.

last updated by: John
