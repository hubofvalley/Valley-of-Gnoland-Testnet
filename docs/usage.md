# Valley of Gnoland - Usage Guide

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

## Test13 to Topaz migration

Topaz uses the same Valley of Gnoland paths as before:

- `~/gno`
- `~/gno/gnoland-data`
- `~/gno/genesis.json`
- `~/.config/gno`
- a user-selected service name, default `gnoland.service`
- `gnoland` and `gnokey` under the current user's `~/go/bin`

Within one OS user, migration is an in-place clean deployment. For side-by-side instances, use separate OS users, separate service names, and separate port prefixes. Each user's `$HOME`, source, data, keyring, and binaries remain isolated.

Run VOG directly as the node OS user. Do not use `sudo bash ...`; VOG requests `sudo` internally only for packages, firewall, and systemd.

During option `1a`, choose one operator-key path:

1. **Reuse local Test13 key** — recommended for an existing validator. The installer lists local keys and requires a key name.
2. **Recover Test13 key** — enter the existing mnemonic into `gnokey`; an existing key name will not be overwritten.
3. **Create new key** — intended for a new operator; an existing key name will not be overwritten.

Before deleting Test13 node data, the installer:

- archives `~/gno/gnoland-data/secrets` when present;
- archives `~/.config/gno` when non-empty;
- saves both under `~/gnoland-migration-backups/<timestamp>/` with mode `600`;
- never deletes the operator keyring.

A fresh Topaz consensus/node key is generated. Existing validators must use the same Test13 operator `g1...` address when registering their Topaz valoper profile.

Invalid moniker, port, key-menu, or existing-key input is prompted again. A real installation failure stops safely and prints its stage, line, failed command, and exit code; Valley of Gnoland then returns to the main menu instead of disappearing silently.

## Menu options

| Option | Behaviour |
|---|---|
| `1a` | Clean-deploys Topaz in the current user's directories, with backup and operator-key selection. It configures official Topaz seeds and the Grand Valley persistent peer, validates the service owner, and rejects occupied ports before cleanup. The chosen prefix must be `01`–`64` and applies to local ABCI (`prefix658`), P2P (`prefix656`), and RPC (`prefix657`) listeners. Success requires those config ports plus RPC network `topaz-1`; failures print diagnostics. |
| `1b` | Updates the source and binaries to the pinned Topaz release after checksum verification. |
| `1c` | Opens the snapshot provider menu and applies the UTSA Topaz snapshot after availability and confirmation checks. It stops the selected service, replaces only `db` and `wal`, restarts the service, and follows live logs. |
| `1d` | Adds persistent peers manually or restores official Topaz seeds plus the Grand Valley persistent peer. |
| `1e` | Shows local/network heights, sync state, peers, disk, and validator address. |
| `1f` | Follows the current user's selected Gnoland service logs. |
| `2a` | Lists/reuses, recovers, or creates an operator key without overwriting an existing name. |
| `2b` | Shows the fresh Topaz consensus `gpub1...` key. |
| `2c` | Previews and optionally broadcasts Topaz valoper registration. |
| `2d` | Queries a path or shows Topaz candidate and active-validator realms. |
| `3a`–`3d` | Restart, stop, delete node data, or back up node secrets. |

## Recommended flow

1. Record the Test13 operator `g1...` address and ensure its mnemonic is backed up offline.
2. Run `1a`, select reuse/recovery, and verify the listed address matches Test13.
3. Let `1e` show the Topaz node is synced.
4. Fund the same operator address from https://topaz.testnets.gno.land/faucet.
5. Use `2b` to obtain the new Topaz consensus public key.
6. Use `2c` to register with the same Test13 operator address.
7. Wait for GovDAO admission through `r/sys/validators/v3`.

## Safety

- Use only the Topaz snapshot URL documented in `docs/snapshots.md`; never apply the former Test13 archive.
- Never share mnemonics or node secrets.
- Inspect backup archives and copy them offline before relying on them.
- Use one OS user, service name, and port prefix per instance.
- VOG never creates or removes global `/usr/local/bin/gnoland` or `/usr/local/bin/gnokey` links.
- Registration creates a candidate profile only; it does not guarantee active-set admission.

last updated by: John
