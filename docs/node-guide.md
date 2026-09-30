# Gno.land Onyx Node - Manual Guide

Official validator source:

- https://github.com/gnolang/gno/blob/chain/onyx/misc/deployments/onyx.gno.land/VALIDATOR.md
- https://github.com/gnolang/gno/releases/tag/chain/onyx

## Network facts

| Field | Value |
|---|---|
| Chain ID | `onyx-1` |
| RPC | `https://rpc.onyx.testnets.gno.land` |
| Faucet | `https://onyx.testnets.gno.land/faucet` |
| Source commit | `5cdbc25fcde0b7569911a4e308ae5d2f6e96c399` |
| Binary release | `v1.5.0` |
| Genesis SHA256 | `4b006fd7ccdec052865accc84dd29b2b76f8b57b2560789a15eedaa88f0e26c5` |

Official persistent peers:

```text
g1x5mlj5ava0dw9vkf4j6admjlzswm6f06p44krn@seed-1.onyx.testnets.gno.land:26656,g1grq5zswt0dlwwe7clr4359w70k2ewgse0gcwck@seed-2.onyx.testnets.gno.land:26656
```

Onyx is a fresh chain. Do not reuse Pearl db/wal, consensus state, or Pearl snapshots.

## Existing Valley layout

```bash
GNO_SOURCE_DIR="$HOME/gno"
GNOLAND_TESTNET_HOME="$HOME/gno/gnoland-data"
GNOLAND_TESTNET_SERVICE_NAME="gnoland-testnet"
GNOKEY_HOME="$HOME/.config/gno"
GNOLAND_BIN="$HOME/go/bin/gnoland"
GNOKEY_BIN="$HOME/go/bin/gnokey"
```

The testnet scripts read `GNOLAND_TESTNET_HOME` and
`GNOLAND_TESTNET_SERVICE_NAME` for instance-specific overrides. The defaults
are `~/gno/gnoland-data` and `gnoland-testnet` (that is, `gnoland-testnet.service`).

Valley preserves this layout during Pearl -> Onyx migration. Back up existing node secrets and the operator keyring first; preserve `GNOKEY_HOME` if you want the same operator `g1...` address.

## Install Onyx release

Pin source to:

```text
5cdbc25fcde0b7569911a4e308ae5d2f6e96c399
```

Official Linux amd64 binary checksums used by Valley:

```text
8dcff48228a881e398d238e3e14760c175c872fb164e85f21e5b4ee94a8b076d  gnoland_linux_amd64
878eb6599161f491a37fdcbd4214477ad28d5d6208f8428f0bffcd3115cd35b4  gnokey_linux_amd64
```

Initialize a fresh Onyx config and fresh Onyx node secrets, then verify the official Onyx genesis checksum above.

## Required/expected configuration

Valley applies the Onyx validator-guide values:

```text
application.prune_strategy = syncable
consensus.timeout_commit = 3s
consensus.peer_gossip_sleep_duration = 10ms
p2p.flush_throttle_timeout = 10ms
p2p.pex = true
mempool.size = 10000
p2p.max_num_outbound_peers = 40
```

Start with:

```bash
gnoland start \
  --data-dir "$GNOLAND_TESTNET_HOME" \
  --chainid onyx-1 \
  --genesis "$GNOLAND_GENESIS" \
  --skip-genesis-sig-verification \
  --log-level info
```

The `--skip-genesis-sig-verification` flag is required by the Onyx validator guide.

## Operator key and validator candidate

Reusing/recovering the Pearl operator key is optional if you want operator-address continuity. It does not migrate validator status, and a fresh Onyx consensus key is still required.

After the node is synced:

```bash
gnoland secrets get --data-dir "$GNOLAND_TESTNET_HOME/secrets" validator_key
```

Fund the operator address using the Onyx faucet, then register a candidate on `gno.land/r/gnops/valopers` using chain `onyx-1`, Onyx RPC, `1000000ugnot` gas fee, and the Onyx guide's gas-wanted value.

Candidate registration does not directly add the node to the active validator set. A GovDAO member must separately create and pass the validator proposal through `r/sys/validators/v0`.

## Snapshot

Onyx snapshot support is currently unavailable. Select menu option `1c` to preserve the existing Valley menu flow, but the helper fails closed and leaves node state unchanged until a chain-specific provider, chain identity, and checksum are verified. Read [Snapshot providers and safety](snapshots.md) for the current status.

Never apply Pearl db/wal or Pearl snapshots to Onyx. An active service must report `onyx-1` with `catching_up=false` through a local loopback RPC before snapshot maintenance can stop it.
