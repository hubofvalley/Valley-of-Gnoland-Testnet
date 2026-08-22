# Sapphire Snapshot Guide

Speed up Gno.land Sapphire node synchronisation using a community snapshot.

## Providers

Grand Valley extends its gratitude to these snapshot providers:

- **UTSA** — `https://share118.utsa.tech/gno_test/gno-test-snapshot.tar.lz4`
- **Hazen Network Solutions** — `https://server-9.hazennetworksolutions.com/gnoland-sapphire/index.json`

Provider availability and current snapshot statistics are checked when you select a provider. Hazen publishes creation time, block height, size, SHA-256, and AppHash-verification metadata through its Sapphire manifest. UTSA exposes the metadata available through HTTP headers; unavailable fields are shown as `Not provided by provider` and are never guessed.

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
3. For Hazen, requires the provider manifest to report chain ID `sapphire-1`.
4. Downloads the archive before stopping Gnoland.
5. Verifies the SHA-256 checksum when the provider publishes one.
6. Validates that the archive contains only `db` and `wal` paths.
7. Optionally archives the current database to `$HOME/gnoland-db-wal-backup-<timestamp>.tar.gz`.
8. Stops the selected Gnoland service and keeps the previous `db` and `wal` in a temporary rollback directory.
9. Extracts the snapshot and restarts the service.
10. Restores the previous database automatically if extraction or service activation fails.
11. Removes the rollback directory after the service is confirmed active, then shows live logs.

Config and node secrets are kept.

## Current Provider Endpoints

UTSA snapshot:

```text
https://share118.utsa.tech/gno_test/gno-test-snapshot.tar.lz4
```

Hazen Sapphire manifest:

```text
https://server-9.hazennetworksolutions.com/gnoland-sapphire/index.json
```

Hazen stable Sapphire archive:

```text
https://server-9.hazennetworksolutions.com/gnoland-db-snapshot.tar.lz4
```

## Before Applying

- Confirm the selected node is on `sapphire-1`.
- Ensure enough free disk space is available for the downloaded snapshot, current database, and optional backup.
- Use the backup prompt if you need a retained copy after a successful restore. The automatic rollback copy is temporary.
- The menu installs missing `curl`, `lz4`, `tar`, and `python3` packages with `apt`.
- A provider without a published checksum is clearly marked; decide whether that trust level is acceptable before continuing.
- Never use a Topaz snapshot on Sapphire.

## After Applying

Watch logs until the node catches up, then check progress with menu option `1e. Show Node Status`.

last updated by: John
