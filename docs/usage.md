# Valley of Gnoland - Usage Guide

Valley of Gnoland now targets the Gno.land **Onyx** testnet (`onyx-1`). Testnet-specific overrides are `GNOLAND_TESTNET_SERVICE_NAME` and `GNOLAND_TESTNET_HOME`; they default to `gnoland-testnet` and `~/gno/gnoland-data`. The selected data directory is passed explicitly to every `gnoland` init/start/secrets operation and to the systemd unit.

## Run

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

Read-only Onyx Node Doctor:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --json
```

## Pearl to Onyx migration

Onyx is a fresh chain, not a Pearl hardfork. Valley keeps the established paths (`~/gno`, `~/gno/gnoland-data`, `~/.config/gno`, per-user binaries, and the selected service name), but it does **not** reuse Pearl db/wal or consensus state. The default testnet unit is `gnoland-testnet.service`, so the mainnet `gnoland.service` name remains available on the same host.

Menu option `1a` is the migration/fresh-install path. It:

1. verifies the service belongs to the selected OS-user instance;
2. backs up Pearl node secrets and the operator keyring;
3. requires `MIGRATE-TO-ONYX` before destructive cleanup;
4. removes old chain data while preserving the keyring;
5. pins source and binaries to the official Onyx release;
6. verifies the Onyx genesis and binary checksums;
7. creates fresh Onyx node/consensus secrets;
8. applies the official Onyx peers and validator-guide tuning;
9. starts with `--chainid onyx-1 --skip-genesis-sig-verification`;
10. reports success only after local RPC reports `onyx-1` and configured ports match.

Reusing/recovering a Pearl operator key is optional **operator-address continuity only**. It does not migrate validator status.

## Menu options

| Option | Behaviour |
|---|---|
| `1a` | Fresh-installs Onyx or migrates a Pearl installation to Onyx with backups and explicit confirmation. |
| `1b` | Updates only an already-Onyx service to the pinned Onyx binaries; stages and verifies network artifacts before stopping the node. |
| `1c` | Retains the snapshot menu, but Onyx snapshot support is currently unavailable and the helper leaves node state unchanged. |
| `1d` | Adds peers manually or resets to the official Onyx persistent peers. |
| `1e` | Shows local Onyx chain ID, height, sync state, and peer count. |
| `1f` | Follows the selected Gnoland service logs, defaulting to `gnoland-testnet.service`. |
| `1g` | Runs the read-only Onyx Node Doctor. |
| `2a` | Lists/reuses, recovers, or creates an operator key without overwriting an existing name. |
| `2b` | Shows the fresh Onyx consensus `gpub1...` key. |
| `2c` | Broadcasts Onyx valoper candidate registration after confirmation. |
| `2d` | Queries a path or shows Onyx candidate/active-validator realms. |
| `3a`–`3d` | Restart, stop, delete Onyx node data, or back up Onyx node secrets. These actions use `GNOLAND_TESTNET_SERVICE_NAME` and `GNOLAND_TESTNET_HOME`. |

## Recommended validator flow

1. Back up the Pearl operator mnemonic offline if you intend to reuse that address.
2. Run `1a` and complete `MIGRATE-TO-ONYX`.
3. Let `1e` show the node is on `onyx-1` and synced.
4. Fund the chosen operator address at https://onyx.testnets.gno.land/faucet.
5. Use `2b` to read the new Onyx consensus public key.
6. Use `2c` to register a Onyx valoper candidate.
7. Wait for the separate GovDAO proposal/admission step through `r/sys/validators/v0`.

## Safety

- Never copy Pearl db/wal or a Pearl snapshot into Onyx.
- Before updater or snapshot maintenance stops an active Onyx service, local RPC must report `onyx-1` with `catching_up=false`.
- Run VOG as the node OS user, not with `sudo bash ...`; VOG requests sudo only where system access is needed.
- Use one OS user/service name/port prefix per instance.
- Never share mnemonics or node secrets.
- Candidate registration is not active-validator admission.
