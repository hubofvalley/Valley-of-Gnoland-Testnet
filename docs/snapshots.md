# Topaz Snapshot Guide

Speed up Gno.land Topaz node synchronisation using a community snapshot.

## Providers

Grand Valley extends its gratitude to these snapshot providers:

- **UTSA** — `https://share118.utsa.tech/gno_test/gno-test-snapshot.tar.lz4`
- **Hazen Network Solutions** — `https://server-9.hazennetworksolutions.com/gnoland-topaz/`

Provider availability and current snapshot statistics are checked when you select a provider. Hazen publishes creation time, block height, size, SHA-256, and AppHash-verification metadata. UTSA currently exposes update time and size through HTTP headers; unavailable fields are shown as `Not provided by provider` and are never guessed.

## How to Apply a Snapshot

Run Valley of Gnoland:

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

Then select:

```text
1c. Apply Snapshot
```

Choose a provider, review its live statistics, then type `yes` to continue. You can optionally archive the current `db` and `wal` before they are replaced.

## What the Snapshot Script Does

1. Fetches the selected provider's availability and metadata.
2. Shows the snapshot date, height, size, and AppHash-verification status when supplied by the provider.
3. Downloads the archive before stopping Gnoland.
4. Verifies the SHA-256 checksum when the provider publishes one.
5. Validates that the archive contains only `db` and `wal` paths.
6. Optionally archives the current database to `$HOME/gnoland-db-wal-backup-<timestamp>.tar.gz`.
7. Stops the selected Gnoland service and keeps the previous `db` and `wal` in a temporary rollback directory.
8. Extracts the snapshot and restarts the service.
9. Restores the previous database automatically if extraction or service activation fails.
10. Removes the rollback directory after the service is confirmed active, then shows live logs.

Config and node secrets are kept.

## Before Applying

- Confirm the selected node is on `topaz-1`.
- Ensure enough free disk space is available for the downloaded snapshot, current database, and optional backup.
- Use the backup prompt if you need a retained copy after a successful restore. The automatic rollback copy is temporary.
- The menu installs missing `curl`, `lz4`, `tar`, and `python3` packages with `apt`.
- A provider without a published checksum is clearly marked; decide whether that trust level is acceptable before continuing.
- Never use the former Test13 snapshot on Topaz.

## After Applying

Watch logs until the node catches up, then check progress with menu option `1e. Show Node Status`.

last updated by: John
