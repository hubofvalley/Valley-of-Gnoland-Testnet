# Valley of Gnoland - Testnet

Interactive terminal tool by **Grand Valley** to deploy and manage a Gno.land Topaz full node and validator-candidate workflow.

## Network

- Network: `Gno.land Topaz`
- Chain ID: `topaz-1`
- Native denom: `ugnot`
- Source tree / `GNOROOT`: `~/gno`
- Node directory: `~/gno/gnoland-data`
- Operator keyring: `~/.config/gno`
- Genesis file: `~/gno/genesis.json`
- Service: user-selected, default `gnoland.service`
- Per-user binaries: `~/go/bin/gnoland`, `~/go/bin/gnokey`
- RPC: `https://rpc.topaz.testnets.gno.land`
- Faucet: https://topaz.testnets.gno.land/faucet
- Grand Valley validator profile: https://topaz.testnets.gno.land/r/gnops/valopers:g19sqhfxveuzdmf244xsslmwd638l9mjcdq76hym
- Grand Valley persistent peer: `g1yzrxmspjavrkv64hl958d7xrc9vj2w9h0jefhs@peer-gnoland.grandvalleys.com:18656`

Topaz is a new chain. Test13 chain data cannot be reused, but an existing Test13 validator must register on Topaz with the **same operator `g1...` address**. The Topaz node receives a fresh consensus key.

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

## Safe Test13 migration

The installer keeps the established Valley of Gnoland layout. It does not rename the source, node, or service paths.

1. It asks whether to reuse a local Test13 operator key, recover one from its mnemonic, or create a new key.
2. Before replacing Test13 chain data, it backs up existing node secrets and the operator keyring under `~/gnoland-migration-backups/<timestamp>/`.
3. It never deletes `~/.config/gno`.
4. It creates fresh Topaz node and consensus secrets.
5. It shows local operator addresses so existing validators can verify they are reusing the Test13 operator address.
6. Invalid interactive input is prompted again instead of terminating the installer.
7. Runtime failures report the exact installation stage, line, command, and exit code before returning to the main menu.

Within one OS user, migration remains in-place: the installer stops only that user's selected service and replaces only that user's `~/gno/gnoland-data`. Separate OS users, unique service names, and unique port prefixes can run isolated Gnoland instances on the same server.

## Features

- Pinned Topaz source and official release checksums
- Official Topaz genesis verification
- Official Topaz seeds, Grand Valley persistent peer, and required node settings
- Custom ABCI/P2P/RPC port prefix, optional UFW, and systemd service
- Per-user binaries and custom service names for isolated multi-instance deployments
- Service ownership and port-collision guards before destructive work
- Safe operator-key reuse/recovery/new-key flow
- Node status, logs, seed/peer configuration, and transaction preview
- Verified startup gate: success requires a live local RPC reporting `topaz-1`
- Valoper candidate registration on `gno.land/r/gnops/valopers`
- UTSA Topaz snapshot flow with provider selection, availability check, and explicit confirmation

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
