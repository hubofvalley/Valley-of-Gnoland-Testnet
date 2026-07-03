# Valley of Gnoland - Usage Guide

How to run the tool, how to navigate it, and what every menu option does.

## Running the tool

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

Or from a local clone:

```bash
bash resources/valleyofGnoland.sh
```

On first run the script asks for a **service name** (default `gnoland`) and saves it to `~/.bash_profile`.

## Important validator note

Gno.land Test13 does not work like a simple open-staking Cosmos chain. The registration flow creates a validator-candidate profile. A GovDAO member must still create and pass a proposal before the candidate joins the active validator set.

## Menu options explained

### 1. Node Interactions

| Option | What it does | When to use |
|---|---|---|
| **1a. Deploy/Re-deploy Gnoland Node** | Runs the installer: asks moniker, port prefix, optional external P2P host, install method, firewall choice, and service name; installs dependencies, prepares the pinned `chain/test13` Gno source tree at `~/gno`, exports `GNOROOT`, downloads official Test13 binaries to `~/go/bin` or builds from source, verifies binary checksums, runs `gnoland config init` and `gnoland secrets init` from `~/gno`, downloads and verifies genesis at `~/gno/genesis.json`, applies official Test13 sentry peers/settings, and creates a systemd service with `WorkingDirectory=~/gno`. Re-running deletes existing node data under `~/gno/gnoland-data`. | First setup, or clean re-install. |
| **1b. Update Gnoland/Gnokey Binaries** | Stops the service, refreshes the pinned Test13 source tree, downloads pinned official Test13 binaries, verifies checksums, replaces `~/go/bin/gnoland` and `~/go/bin/gnokey`, restarts the service. | When rebuilding the same pinned Test13 binary state. |
| **1c. Add/Reset Peers** | Updates `p2p.persistent_peers` in `~/gno/gnoland-data/config/config.toml` manually or resets to the official Test13 sentry peers. Restart afterwards. | Peer issues or manual peer tuning. |
| **1d. Show Node Status** | Reads local RPC status, prints sync JSON, compares local height with public Test13 RPC height. | Check sync progress before candidate registration. |
| **1e. Show Node Logs** | Live-tails `journalctl -u gnoland -fn 100`. Press Ctrl+C to return. | Debugging, watching sync. |

### 2. Validator/Key Interactions

| Option | What it does | When to use |
|---|---|---|
| **2a. Create/Recover/List Operator Key** | Uses `gnokey` with `GNOKEY_HOME` to create, recover, or list operator keys. New mnemonics must be stored offline. | Before registering a valoper candidate. |
| **2b. Show Validator Consensus Pubkey** | Prints the node validator key from `gnoland secrets get validator_key`; use the `gpub1...` value. | Needed for valoper candidate registration. |
| **2c. Register Valoper Candidate** | Guided `gnokey maketx call` for `gno.land/r/gnops/valopers Register`. Shows the full transaction preview and asks before broadcasting. | After node sync and faucet funding. |
| **2d. Query / Show Valoper Pages** | Runs manual ABCI query paths or prints the candidate/active-validator realm URLs. | Lightweight checks after registration. |

### 3. Node Management

| Option | What it does | When to use |
|---|---|---|
| **3a. Restart Gnoland Node** | `systemctl restart gnoland`. | After config changes. |
| **3b. Stop Gnoland Node** | `systemctl stop gnoland`. | Maintenance. |
| **3c. Delete Gnoland Node** | Stops and disables service, removes service file, deletes `~/gno/gnoland-data`, removes binaries, and cleans Gno env vars. It does not delete `GNOKEY_HOME`. | Decommissioning or clean rebuild. |
| **3d. Backup Node Secrets** | Archives `~/gno/gnoland-data/secrets` into a timestamped `tar.gz` in `$HOME` with `600` permissions. | Immediately after deploy and before destructive actions. |
| **3e. Repair Test13 Stdlib Root** | Refreshes the pinned `~/gno` source tree and rewrites `gnoland.service` to start from `~/gno` with `GNOROOT` set, then restarts the service. | Fix `panic: gno was unable to determine GNOROOT` or `panic: failed loading stdlib "errors": does not exist` without deleting node data. |

### 4. Show Endpoints & Useful Links

Official docs, release, validator guide, faucet, status page, valoper candidate page, active-validator realm, and Grand Valley contacts.

### 5. Show Guidelines

Short in-tool checklist for first-time flow and candidate/active-set warning.

### 6. Exit

Leaves the script. Run `source ~/.bash_profile && hash -r` in the current shell if you need newly exported variables immediately.

## Recommended first-time flow

1. `1a` deploy node and let it sync
2. `2a` create or recover operator key
3. Fund the `g1...` operator address from https://test13.testnets.gno.land/faucet
4. `2b` copy the `gpub1...` consensus pubkey
5. `2c` register valoper candidate
6. `3d` backup node secrets
7. Prepare GovDAO-facing validator narrative; candidate registration alone is not active-set admission

## Safety notes

- Use burner/testnet-only keys.
- Never share mnemonics or node secrets.
- Public P2P must be reachable if the node is expected to participate seriously.
- Test13 genesis startup requires `-skip-genesis-sig-verification`; upstream documents this as required for historical replay.
- Test13 `gnoland` needs `GNOROOT` and the matching Gno source tree at runtime because stdlibs load from `gnovm/stdlibs`; missing `GNOROOT` can make even plain `gnoland` panic before help output.
