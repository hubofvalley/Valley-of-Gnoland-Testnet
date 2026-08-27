# Valley of Gnoland - Testnet

Interactive terminal tool by **Grand Valley** to deploy, migrate, inspect, and manage a Gno.land **Pearl** full node and validator-candidate workflow.

## Network

- Network: `Gno.land Pearl`
- Chain ID: `pearl-1`
- Native denom: `ugnot`
- Release: `chain/pearl`
- Pinned upstream commit: `c4c72fdd288c757e8da0d93aae867fa479b1b15c`
- Source tree / `GNOROOT`: `~/gno`
- Node directory: `~/gno/gnoland-data`
- Operator keyring: `~/.config/gno`
- Genesis file: `~/gno/genesis.json`
- Service: user-selected, default `gnoland.service`
- Per-user binaries: `~/go/bin/gnoland`, `~/go/bin/gnokey`
- RPC: `https://rpc.pearl.testnets.gno.land`
- Faucet: https://pearl.testnets.gno.land/faucet

Pearl is a **fresh chain**, not a Sapphire hardfork. Sapphire chain data, db/wal, consensus state, and snapshots cannot be reused. Valley of Gnoland can preserve/recover the existing operator key if you want the same `g1...` operator address, but key reuse does **not** migrate validator status. Pearl candidate registration and GovDAO admission are separate new-chain steps.

## Run

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

Read-only Pearl Node Doctor:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor
```

Machine-readable output:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --json
```

## Safe Sapphire -> Pearl migration

The migration path intentionally keeps the established Valley of Gnoland filesystem layout while replacing only chain-specific state.

1. Stop only the selected Gnoland service after verifying service ownership.
2. Back up existing Sapphire node secrets and the operator keyring under `~/gnoland-migration-backups/<timestamp>/`.
3. Never delete `~/.config/gno` during migration.
4. Remove old Sapphire chain data and genesis; do not copy Sapphire db/wal into Pearl.
5. Pin the Gno source to the official Pearl release commit and verify the official Pearl binary checksums.
6. Download and verify the Pearl genesis SHA-256.
7. Create fresh Pearl node/consensus secrets.
8. Apply the official Pearl persistent peers and validator-guide tuning.
9. Start with `--chainid pearl-1 --genesis genesis.json --skip-genesis-sig-verification`.
10. Report success only after the local RPC returns `pearl-1` and the configured local ports match.

The migration prompt is deliberately explicit: `MIGRATE-TO-PEARL`.

## Validator candidate flow

After the node is synced:

1. Reuse/recover a Sapphire operator key only if you want operator-address continuity, or create a new key.
2. Fund that address using the Pearl faucet.
3. Read the fresh Pearl consensus public key with `gnoland secrets get validator_key`.
4. Register a candidate on `gno.land/r/gnops/valopers` using `pearl-1` and the Pearl RPC.
5. A GovDAO member must separately create and pass a validator proposal before the candidate joins the active validator set.

## Snapshot safety

Snapshot application is currently **disabled for Pearl**. The previous UTSA/Hazen configuration was Sapphire-specific. Valley of Gnoland fails closed instead of risking a Sapphire snapshot being applied to `pearl-1`. The snapshot feature should be re-enabled only after a Pearl-specific provider and verification metadata are reviewed and pinned.

## Features

- Pinned Pearl source, genesis checksum, and official Linux amd64 release checksums
- Official Pearl persistent peers and required startup flag
- Sapphire -> Pearl fresh-chain migration with operator-key backup/preservation
- Custom ABCI/P2P/RPC port prefix, optional UFW, and systemd service
- Per-user binaries and service ownership guards for isolated instances
- Node status, logs, peer management, and validator candidate registration
- Read-only Pearl Node Doctor with human and JSON output
- Fail-closed snapshot path until Pearl snapshots are independently verified

## Documentation

- [Usage guide](docs/usage.md)
- [Manual Pearl node guide](docs/node-guide.md)
- [Node Doctor guide](docs/node-doctor.md)
- [Snapshot safety](docs/snapshots.md)

## Upstream sources

- Pearl validator guide: https://github.com/gnolang/gno/blob/chain/pearl/misc/deployments/pearl.gno.land/VALIDATOR.md
- Pearl release: https://github.com/gnolang/gno/releases/tag/chain/pearl

## Connect with Grand Valley

- X: https://x.com/bacvalley
- GitHub: https://github.com/hubofvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**
