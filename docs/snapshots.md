# Snapshot Guide

Speed up Gno.land Test13 node synchronization using the UTSA snapshot.

## Provider

Grand Valley extends its gratitude to **UTSA** for providing snapshot support.

Snapshot URL:

```text
https://share118.utsa.tech/gno_test13/gno-test13-snapshot.tar.lz4
```

## How to Apply Snapshot

Run Valley of Gnoland:

```bash
bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh)
```

Then select:

```text
1c. Apply Snapshot
```

Choose **UTSA**, review the warning, then type `yes` to apply it.

## What the Snapshot Script Does

1. Shows UTSA as the snapshot provider and checks snapshot availability
2. Stops `gnoland.service` or a running `gnoland start` process
3. Deletes the old chain database folders:
   - `~/gno/gnoland-data/db`
   - `~/gno/gnoland-data/wal`
4. Streams and extracts the UTSA snapshot into `~/gno/gnoland-data/`
5. Restarts `gnoland.service`
6. Shows live Gnoland logs with `journalctl`

Config and node secrets are kept.

## Manual Commands

These are the direct commands used by the menu flow:

```bash
systemctl stop gnoland 2>/dev/null || pkill -f "gnoland start" 2>/dev/null || true
rm -rf ~/gno/gnoland-data/db ~/gno/gnoland-data/wal
curl -o - -L https://share118.utsa.tech/gno_test13/gno-test13-snapshot.tar.lz4 | lz4 -c -d - | tar -x -C $HOME/gno/gnoland-data/
systemctl restart gnoland && journalctl -u gnoland -f -o cat
```

If your service name is not `gnoland`, use the menu flow or replace the service name in the manual commands.

## Before Applying

- Backup node secrets first if this node matters.
- Make sure `curl`, `lz4`, and `tar` are available. The menu script installs missing dependencies with `apt`.
- Confirm the node directory is `~/gno/gnoland-data`.

## After Applying

Watch logs until the node catches up:

```bash
journalctl -u gnoland -f -o cat
```

Check sync status from the menu with `1e. Show Node Status`.
