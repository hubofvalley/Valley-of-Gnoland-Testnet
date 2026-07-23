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
- `gnoland.service`
- `gnoland` and `gnokey` commands via `/usr/local/bin`

Because these names remain unchanged, migration is an in-place clean deployment. Test13 and Topaz cannot run side by side through this installer.

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
| `1a` | Clean-deploys Topaz in the existing directories, with backup and operator-key selection. The chosen two-digit prefix applies to local ABCI (`prefix658`), P2P (`prefix656`), and RPC (`prefix657`) listeners. Success requires those config ports plus RPC network `topaz-1`; failures print diagnostics. |
| `1b` | Updates the source and binaries to the pinned Topaz release after checksum verification. |
| `1c` | Reports that no verified Topaz snapshot is available; makes no changes. |
| `1d` | Adds persistent peers manually or restores official Topaz seeds. |
| `1e` | Shows local/network heights, sync state, peers, disk, and validator address. |
| `1f` | Follows `gnoland.service` logs. |
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

- Never apply a Test13 snapshot to Topaz.
- Never share mnemonics or node secrets.
- Inspect backup archives and copy them offline before relying on them.
- Registration creates a candidate profile only; it does not guarantee active-set admission.

last updated by: John
