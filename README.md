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
- Service: `gnoland.service`
- Command links: `/usr/local/bin/gnoland`, `/usr/local/bin/gnokey`
- RPC: `https://rpc.topaz.testnets.gno.land`
- Faucet: https://topaz.testnets.gno.land/faucet

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

The migration is in-place because the directory and service names remain unchanged. The installer stops `gnoland.service` and replaces `~/gno/gnoland-data`; it does not run Test13 and Topaz in parallel.

## Features

- Pinned Topaz source and official release checksums
- Official Topaz genesis verification
- Official Topaz seeds and required node settings
- Custom RPC/P2P port prefix, optional UFW, and systemd service
- Safe operator-key reuse/recovery/new-key flow
- Node status, logs, seed/peer configuration, and transaction preview
- Verified startup gate: success requires a live local RPC reporting `topaz-1`
- Valoper candidate registration on `gno.land/r/gnops/valopers`
- Snapshot safety gate: Test13 snapshots are blocked

## Documentation

- [Usage guide](docs/usage.md)
- [Manual node guide](docs/node-guide.md)
- [Snapshot status](docs/snapshots.md)

Candidate registration does not add a node directly to the active validator set. A GovDAO member must create and pass the validator proposal.

## Connect with Grand Valley

- X: https://x.com/bacvalley
- GitHub: https://github.com/hubofvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**

last updated by: John
