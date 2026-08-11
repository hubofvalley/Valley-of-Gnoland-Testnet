# Valley of Gnoland - Testnet

Interactive terminal tool by **Grand Valley** to deploy and manage a Gno.land Sapphire full node and validator-candidate workflow.

## Network

- Network: `Gno.land Sapphire`
- Chain ID: `sapphire-1`
- Native denom: `ugnot`
- Source tree / `GNOROOT`: `~/gno`
- Node directory: `~/gno/gnoland-data`
- Operator keyring: `~/.config/gno`
- Genesis file: `~/gno/genesis.json`
- Service: user-selected, default `gnoland.service`
- Per-user binaries: `~/go/bin/gnoland`, `~/go/bin/gnokey`
- RPC: `https://rpc.sapphire.testnets.gno.land`
- Faucet: https://sapphire.testnets.gno.land/faucet

Sapphire is a new chain. Topaz chain data cannot be reused, but an existing Topaz validator must register on Sapphire with the **same operator `g1...` address**. The Sapphire node receives a fresh consensus key.

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

## Safe Topaz migration

The installer keeps the established Valley of Gnoland layout. It does not rename the source, node, or service paths.

1. It asks whether to reuse a local Topaz operator key, recover one from its mnemonic, or create a new key.
2. Before replacing Topaz chain data, it backs up existing node secrets and the operator keyring under `~/gnoland-migration-backups/<timestamp>/`.
3. It never deletes `~/.config/gno`.
4. It creates fresh Sapphire node and consensus secrets.
5. It shows local operator addresses so existing validators can verify they are reusing the Topaz operator address.
6. Invalid interactive input is prompted again instead of terminating the installer.
7. Runtime failures report the exact installation stage, line, command, and exit code before returning to the main menu.

Within one OS user, migration remains in-place: the installer stops only that user's selected service and replaces only that user's `~/gno/gnoland-data`. Separate OS users, unique service names, and unique port prefixes can run isolated Gnoland instances on the same server.

## Features

- Pinned Sapphire source and official release checksums
- Official Sapphire genesis verification
- Official Sapphire nodes configured as persistent peers
- Custom ABCI/P2P/RPC port prefix, optional UFW, and systemd service
- Per-user binaries and custom service names for isolated multi-instance deployments
- Service ownership and port-collision guards before destructive work
- Safe operator-key reuse/recovery/new-key flow
- Node status, logs, persistent-peer configuration, and transaction preview
- Verified startup gate: success requires a live local RPC reporting `sapphire-1`
- Valoper candidate registration on `gno.land/r/gnops/valopers`
- Explicit snapshot guard that blocks incompatible Topaz archives

## Documentation

- [Usage guide](docs/usage.md)
- [Manual node guide](docs/node-guide.md)
- [Snapshot guide](docs/snapshots.md)

Candidate registration does not add a node directly to the active validator set. A GovDAO member must create and pass the validator proposal.

## Connect with Grand Valley

- X: https://x.com/bacvalley
- GitHub: https://github.com/hubofvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**

last updated by: John
