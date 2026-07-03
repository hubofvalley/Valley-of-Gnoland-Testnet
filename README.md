# Valley of Gnoland - Testnet

Interactive terminal tool by **Grand Valley** to deploy and manage a Gno.land Test13 full node and validator-candidate workflow.

## System Requirements

| Category  | Requirements |
| --------- | ------------ |
| CPU       | 4+ vCPU      |
| RAM       | 8+ GB        |
| Storage   | 200+ GB SSD  |
| Bandwidth | 100+ MBit/s  |

- Network: `Gno.land Test13`
- Chain ID: `test-13`
- Native denom: `ugnot`
- Binaries: `~/go/bin/gnoland`, `~/go/bin/gnokey`
- Source tree / `GNOROOT`: `~/gno`
- Node directory: `~/gno/gnoland-data`
- Genesis file: `~/gno/genesis.json`
- Service: `gnoland.service`
- RPC: `https://rpc.test13.testnets.gno.land`
- Genesis: https://github.com/gnolang/gno/releases/download/chain/test13/genesis.json
- Faucet: https://test13.testnets.gno.land/faucet

Important: Test13 validator registration only lists you as a **candidate**. A GovDAO member must create and pass a proposal before the node joins the active validator set.

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

## Documentation

- **[Usage guide - every menu option explained](docs/usage.md)**
- [Manual node guide (commands behind the menu)](docs/node-guide.md)

## Features

- Deploy/re-deploy a Gno.land Test13 node following the official Test13 validator procedure
- Pin and configure `GNOROOT` so `gnoland` can find the matching Test13 Gno source tree
- Verify the official Test13 genesis SHA256 before starting
- Configure official sentry peers and Test13-required node settings
- Custom RPC/P2P port prefix, optional UFW, systemd service
- Node status, live logs, peer config reset
- Create/recover `gnokey` operator key
- Show consensus public key
- Register a validator-candidate profile on `gno.land/r/gnops/valopers`
- Backup node secrets, restart/stop/delete node
- Repair the Test13 stdlib root on an existing failed service

## Recommended validator-candidate flow

1. `1a` Deploy node, wait until `1d` shows the node is synced
2. `2a` Create or recover operator key
3. Fund the `g1...` operator address via https://test13.testnets.gno.land/faucet
4. `2b` Show consensus pubkey
5. `2c` Register valoper candidate
6. `3d` Backup node secrets
7. Prepare GovDAO-facing validator narrative; candidate registration is not active-set admission

## Connect with Grand Valley

- X: https://x.com/bacvalley
- GitHub: https://github.com/hubofvalley
- Email: letsbuidltogether@grandvalleys.com

**Let's Buidl Gnoland Together - Grand Valley**
