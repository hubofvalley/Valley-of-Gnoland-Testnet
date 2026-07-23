# Topaz Snapshot Guide

Speed up Gno.land Topaz node synchronisation using the UTSA snapshot.

## Provider

Grand Valley extends its gratitude to **UTSA** for providing snapshot support.

Snapshot URL:

```text
https://share118.utsa.tech/gno_test/gno-test-snapshot.tar.lz4
```

## How to Apply the Snapshot

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

1. Shows UTSA as the snapshot provider and checks snapshot availability.
2. Stops the selected Gnoland service or a running `gnoland start` process.
3. Deletes only the old `db` and `wal` folders from the selected `GNOLAND_HOME`.
4. Streams and extracts the UTSA Topaz snapshot into `GNOLAND_HOME`.
5. Restarts the selected Gnoland service.
6. Shows live Gnoland logs with `journalctl`.

Config and node secrets are kept.

## Manual Commands

These commands assume the default service and node directory:

```bash
systemctl stop gnoland 2>/dev/null || pkill -f "gnoland start" 2>/dev/null || true
rm -rf "$HOME/gno/gnoland-data/db" "$HOME/gno/gnoland-data/wal"
curl -o - -fL https://share118.utsa.tech/gno_test/gno-test-snapshot.tar.lz4 \
  | lz4 -c -d - \
  | tar -x -C "$HOME/gno/gnoland-data/"
systemctl restart gnoland
journalctl -u gnoland -f -o cat
```

If your service name or node directory differs, use the menu flow or replace the defaults carefully.

## Before Applying

- Back up node secrets first if this node matters.
- Confirm the selected node is on `topaz-1`.
- Ensure enough free disk space is available.
- The menu installs missing `curl`, `lz4`, and `tar` packages with `apt`.
- Never use the former Test13 snapshot on Topaz.

## After Applying

Watch logs until the node catches up, then check progress with menu option `1e. Show Node Status`.

last updated by: John
