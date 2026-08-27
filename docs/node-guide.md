# Gno.land Pearl Node - Manual Guide

Official validator source:

- https://github.com/gnolang/gno/blob/chain/pearl/misc/deployments/pearl.gno.land/VALIDATOR.md
- https://github.com/gnolang/gno/releases/tag/chain/pearl

## Network facts

| Field | Value |
|---|---|
| Chain ID | `pearl-1` |
| RPC | `https://rpc.pearl.testnets.gno.land` |
| Faucet | `https://pearl.testnets.gno.land/faucet` |
| Release commit | `c4c72fdd288c757e8da0d93aae867fa479b1b15c` |
| Genesis SHA256 | `c45fe60c8c8a1f859d9e4d5aad7ce4d100ff0eb78302e71318ba0de481a8dc91` |

Official persistent peers:

```text
g1m37xukfq6yl555k93fcyzns83qnmgyax9zm875@seed-1.pearl.testnets.gno.land:26656,g1ngukqd3khekaqjf90k45cglzm0l25wwzl2fkn2@seed-2.pearl.testnets.gno.land:26656
```

Pearl is a fresh chain. Do not reuse Sapphire db/wal, consensus state, or Sapphire snapshots.

## Existing Valley layout

```bash
GNO_SOURCE_DIR="$HOME/gno"
GNOLAND_HOME="$HOME/gno/gnoland-data"
GNOKEY_HOME="$HOME/.config/gno"
GNOLAND_BIN="$HOME/go/bin/gnoland"
GNOKEY_BIN="$HOME/go/bin/gnokey"
```

Valley preserves this layout during Sapphire -> Pearl migration. Back up existing node secrets and the operator keyring first; preserve `GNOKEY_HOME` if you want the same operator `g1...` address.

## Install Pearl release

Pin source to:

```text
c4c72fdd288c757e8da0d93aae867fa479b1b15c
```

Official Linux amd64 binary checksums used by Valley:

```text
055b24001a31de7054649a049c9f9db5282965713814b84f7f864e8e6efa237d  gnoland_linux_amd64
a69017c6e9ce9d77d3bd2f1e811731f6353e0deba5da4f620672d58e5fcec804  gnokey_linux_amd64
```

Initialize a fresh Pearl config and fresh Pearl node secrets, then verify the official Pearl genesis checksum above.

## Required/expected configuration

Valley applies the Pearl validator-guide values:

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
  --chainid pearl-1 \
  --genesis genesis.json \
  --skip-genesis-sig-verification \
  --log-level info
```

The `--skip-genesis-sig-verification` flag is required by the Pearl validator guide.

## Operator key and validator candidate

Reusing/recovering the Sapphire operator key is optional if you want operator-address continuity. It does not migrate validator status, and a fresh Pearl consensus key is still required.

After the node is synced:

```bash
gnoland secrets get validator_key
```

Fund the operator address using the Pearl faucet, then register a candidate on `gno.land/r/gnops/valopers` using chain `pearl-1`, Pearl RPC, `1000000ugnot` gas fee, and the Pearl guide's gas-wanted value.

Candidate registration does not directly add the node to the active validator set. A GovDAO member must separately create and pass the validator proposal through `r/sys/validators/v3`.

## Snapshot

Valley intentionally disables snapshot application until a Pearl-specific provider and verification metadata are reviewed. Do not apply the previous Sapphire UTSA/Hazen archives to Pearl.
