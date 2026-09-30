# Valley of Gnoland - Testnet

Interactive terminal tool by **Grand Valley** to deploy, migrate, inspect, and manage a Gno.land **Onyx** full node and validator-candidate workflow.

## Network

- Network: `Gno.land Onyx`
- Chain ID: `onyx-1`
- Native denom: `ugnot`
- Release: `chain/onyx`
- Binary release: `v1.5.0`
- Pinned upstream commit: `5cdbc25fcde0b7569911a4e308ae5d2f6e96c399`
- Source tree / `GNOROOT`: `~/gno`
- Node directory: `~/gno/gnoland-data` (override with `GNOLAND_TESTNET_HOME`)
- Operator keyring: `~/.config/gno`
- Genesis file: `~/gno/genesis.json`
- Service: user-selected, default `gnoland-testnet.service`
- Per-user binaries: `~/go/bin/gnoland`, `~/go/bin/gnokey`
- RPC: `https://rpc.onyx.testnets.gno.land`
- Faucet: https://onyx.testnets.gno.land/faucet

Onyx is a **fresh chain**, not a Pearl hardfork. Testnet-specific runtime overrides are `GNOLAND_TESTNET_HOME` and `GNOLAND_TESTNET_SERVICE_NAME`; the defaults are `~/gno/gnoland-data` and `gnoland-testnet.service`. Pearl chain data, db/wal, consensus state, and snapshots cannot be reused. Valley of Gnoland can preserve/recover the existing operator key if you want the same `g1...` operator address, but key reuse does **not** migrate validator status. Onyx candidate registration and GovDAO admission are separate new-chain steps.

## Run

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

Read-only Onyx Node Doctor:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor
```

Machine-readable output:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --json
```

## Safe Pearl -> Onyx migration

The migration path intentionally keeps the established Valley of Gnoland filesystem layout while replacing only chain-specific state.

1. Stop only the selected Gnoland service after verifying service ownership.
2. Back up existing Pearl node secrets and the operator keyring under `~/gnoland-migration-backups/<timestamp>/`.
3. Never delete `~/.config/gno` during migration.
4. Remove old Pearl chain data and genesis; do not copy Pearl db/wal into Onyx.
5. Pin the Gno source to the official Onyx release commit and verify the official Onyx binary checksums.
6. Download and verify the Onyx genesis SHA-256.
7. Create fresh Onyx node/consensus secrets.
8. Apply the official Onyx persistent peers and validator-guide tuning.
9. Start with `--chainid onyx-1 --genesis genesis.json --skip-genesis-sig-verification`.
10. Report success only after the local RPC returns `onyx-1` and the configured local ports match.

The migration prompt is deliberately explicit: `MIGRATE-TO-ONYX`.

## Validator candidate flow

After the node is synced:

1. Reuse/recover a Pearl operator key only if you want operator-address continuity, or create a new key.
2. Fund that address using the Onyx faucet.
3. Read the fresh Onyx consensus public key with `gnoland secrets get --data-dir "$GNOLAND_TESTNET_HOME/secrets" validator_key`.
4. Register a candidate on `gno.land/r/gnops/valopers` using `onyx-1` and the Onyx RPC.
5. A GovDAO member must separately create and pass a validator proposal before the candidate joins the active validator set.

## Snapshot safety

Onyx snapshot support is currently unavailable. The menu option remains visible for UX compatibility, but no chain-specific provider, chain identity, and checksum have been verified. Use normal P2P synchronization through the official Onyx peers.

Before any active Onyx service is stopped, the tooling verifies a local loopback RPC reports `onyx-1` with `catching_up=false`. The pinned Onyx release predates upstream crash-safety fix gnolang/gno#6085, so maintenance fails closed when sync state cannot be verified.

## Features

- Pinned Onyx source, genesis checksum, and official Linux amd64 release checksums
- Official Onyx persistent peers and required startup flag
- Pearl -> Onyx fresh-chain migration with operator-key backup/preservation
- Custom ABCI/P2P/RPC port prefix, optional UFW, and systemd service
- Per-user binaries and service ownership guards for isolated instances
- Node status, logs, peer management, and validator candidate registration
- Read-only Onyx Node Doctor with human and JSON output
- Snapshot menu preserved with fail-closed availability checks until a chain-specific Onyx provider is verified
- Updater artifact staging and checksum verification before the node maintenance boundary

## Documentation

- [Usage guide](docs/usage.md)
- [Manual Onyx node guide](docs/node-guide.md)
- [Node Doctor guide](docs/node-doctor.md)
- [Snapshot providers and safety](docs/snapshots.md)

## Upstream sources

- Onyx validator guide: https://github.com/gnolang/gno/blob/chain/onyx/misc/deployments/onyx.gno.land/VALIDATOR.md
- Onyx release: https://github.com/gnolang/gno/releases/tag/chain/onyx

## Connect with Grand Valley

- X: https://x.com/bacvalley
- GitHub: https://github.com/hubofvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**
