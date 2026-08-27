# Valley of Gnoland - Usage Guide

Valley of Gnoland now targets the Gno.land **Pearl** testnet (`pearl-1`).

## Run

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

Read-only Pearl Node Doctor:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --json
```

## Sapphire to Pearl migration

Pearl is a fresh chain, not a Sapphire hardfork. Valley keeps the established paths (`~/gno`, `~/gno/gnoland-data`, `~/.config/gno`, per-user binaries, and the selected service name), but it does **not** reuse Sapphire db/wal or consensus state.

Menu option `1a` is the migration/fresh-install path. It:

1. verifies the service belongs to the selected OS-user instance;
2. backs up Sapphire node secrets and the operator keyring;
3. requires `MIGRATE-TO-PEARL` before destructive cleanup;
4. removes old chain data while preserving the keyring;
5. pins source and binaries to the official Pearl release;
6. verifies the Pearl genesis and binary checksums;
7. creates fresh Pearl node/consensus secrets;
8. applies the official Pearl peers and validator-guide tuning;
9. starts with `--chainid pearl-1 --skip-genesis-sig-verification`;
10. reports success only after local RPC reports `pearl-1` and configured ports match.

Reusing/recovering a Sapphire operator key is optional **operator-address continuity only**. It does not migrate validator status.

## Menu options

| Option | Behaviour |
|---|---|
| `1a` | Fresh-installs Pearl or migrates a Sapphire installation to Pearl with backups and explicit confirmation. |
| `1b` | Updates only an already-Pearl service to the pinned Pearl binaries; refuses Sapphire services. |
| `1c` | Fails closed until a Pearl-specific snapshot provider is reviewed and pinned. |
| `1d` | Adds peers manually or resets to the official Pearl persistent peers. |
| `1e` | Shows local Pearl chain ID, height, sync state, and peer count. |
| `1f` | Follows the selected Gnoland service logs. |
| `1g` | Runs the read-only Pearl Node Doctor. |
| `2a` | Lists/reuses, recovers, or creates an operator key without overwriting an existing name. |
| `2b` | Shows the fresh Pearl consensus `gpub1...` key. |
| `2c` | Broadcasts Pearl valoper candidate registration after confirmation. |
| `2d` | Queries a path or shows Pearl candidate/active-validator realms. |
| `3a`–`3d` | Restart, stop, delete Pearl node data, or back up Pearl node secrets. |

## Recommended validator flow

1. Back up the Sapphire operator mnemonic offline if you intend to reuse that address.
2. Run `1a` and complete `MIGRATE-TO-PEARL`.
3. Let `1e` show the node is on `pearl-1` and synced.
4. Fund the chosen operator address at https://pearl.testnets.gno.land/faucet.
5. Use `2b` to read the new Pearl consensus public key.
6. Use `2c` to register a Pearl valoper candidate.
7. Wait for the separate GovDAO proposal/admission step through `r/sys/validators/v3`.

## Safety

- Never copy Sapphire db/wal or a Sapphire snapshot into Pearl.
- Run VOG as the node OS user, not with `sudo bash ...`; VOG requests sudo only where system access is needed.
- Use one OS user/service name/port prefix per instance.
- Never share mnemonics or node secrets.
- Candidate registration is not active-validator admission.
