# Valley of Gnoland - Usage Guide

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

## Topaz to Sapphire migration

Sapphire uses the same Valley of Gnoland paths as before:

- `~/gno`
- `~/gno/gnoland-data`
- `~/gno/genesis.json`
- `~/.config/gno`
- a user-selected service name, default `gnoland.service`
- `gnoland` and `gnokey` under the current user's `~/go/bin`

Within one OS user, migration is an in-place clean deployment. For side-by-side instances, use separate OS users, separate service names, and separate port prefixes. Each user's `$HOME`, source, data, keyring, and binaries remain isolated.

Run VOG directly as the node OS user. Do not use `sudo bash ...`; VOG requests `sudo` internally only for packages, firewall, and systemd.

During option `1a`, choose one operator-key path:

1. **Reuse local Topaz key** — recommended for an existing validator. The installer lists local keys and requires a key name.
2. **Recover Topaz key** — enter the existing mnemonic into `gnokey`; an existing key name will not be overwritten.
3. **Create new key** — intended for a new operator; an existing key name will not be overwritten.

Before deleting Topaz node data, the installer:

- archives `~/gno/gnoland-data/secrets` when present;
- archives `~/.config/gno` when non-empty;
- saves both under `~/gnoland-migration-backups/<timestamp>/` with mode `600`;
- never deletes the operator keyring.

A fresh Sapphire consensus/node key is generated. Existing validators must use the same Topaz operator `g1...` address when registering their Sapphire valoper profile.

Invalid moniker, port, key-menu, or existing-key input is prompted again. A real installation failure stops safely and prints its stage, line, failed command, and exit code; Valley of Gnoland then returns to the main menu instead of disappearing silently.

## Menu options

| Option | Behaviour |
|---|---|
| `1a` | Clean-deploys Sapphire in the current user's directories, with backup and operator-key selection. It configures the official Sapphire persistent peers, validates the service owner, and rejects occupied ports before cleanup. The chosen prefix must be `01`–`64` and applies to local ABCI (`prefix658`), P2P (`prefix656`), and RPC (`prefix657`) listeners. Success requires those config ports plus RPC network `sapphire-1`; failures print diagnostics. |
| `1b` | Updates the source and binaries to the pinned Sapphire release after checksum verification. |
| `1c` | Reports that snapshots are temporarily unavailable. Topaz archives are blocked because they are incompatible with `sapphire-1`. |
| `1d` | Adds persistent peers manually or restores the official Sapphire persistent peers. |
| `1e` | Shows local/network heights, sync state, peers, disk, and validator address. |
| `1f` | Follows the current user's selected Gnoland service logs. |
| `2a` | Lists/reuses, recovers, or creates an operator key without overwriting an existing name. |
| `2b` | Shows the fresh Sapphire consensus `gpub1...` key. |
| `2c` | Previews and optionally broadcasts Sapphire valoper registration. |
| `2d` | Queries a path or shows Sapphire candidate and active-validator realms. |
| `3a`–`3d` | Restart, stop, delete node data, or back up node secrets. |

## Recommended flow

1. Record the Topaz operator `g1...` address and ensure its mnemonic is backed up offline.
2. Run `1a`, select reuse/recovery, and verify the listed address matches Topaz.
3. Let `1e` show the Sapphire node is synced.
4. Fund the same operator address from https://sapphire.testnets.gno.land/faucet.
5. Use `2b` to obtain the new Sapphire consensus public key.
6. Use `2c` to register with the same Topaz operator address.
7. Wait for GovDAO admission through `r/sys/validators/v3`.

## Safety

- Never apply a Topaz snapshot archive to Sapphire. Snapshot support remains blocked until a Sapphire-specific provider is verified.
- Never share mnemonics or node secrets.
- Inspect backup archives and copy them offline before relying on them.
- Use one OS user, service name, and port prefix per instance.
- VOG never creates or removes global `/usr/local/bin/gnoland` or `/usr/local/bin/gnokey` links.
- Registration creates a candidate profile only; it does not guarantee active-set admission.

last updated by: John
