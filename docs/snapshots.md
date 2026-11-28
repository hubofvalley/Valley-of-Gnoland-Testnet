# Onyx Snapshots

Onyx snapshot support is currently unavailable. The menu option remains visible for UX compatibility, but `resources/apply_snapshot.sh` fails closed because no chain-specific provider, chain identity, and checksum have been verified. This restriction is specific to the Valley snapshot helper, not a claim that no upstream snapshot service exists.

For a fresh node without a verified snapshot, follow the [official Onyx upgrade ledger](https://github.com/gnolang/gno/blob/chain/mainnet/misc/deployments/onyx.gno.land/UPGRADES.md) for historical P2P replay. As of November 28, 2026, the ledger requires `v1.7.1-rc.1` with its matching `GNOROOT` from genesis through block `1203400`, including restarts at earlier historical halts, then `v1.8.0-rc.1` with its matching `GNOROOT`. Starting from genesis directly on `v1.8.0-rc.1` cannot replay the earlier non-canonical transactions. The Valley runtime pins and install/update helpers have not yet been aligned with this replay path; do not use them as a current fresh-node recovery procedure.

Onyx is a fresh chain. Pearl database state, WAL data, and snapshots must never be reused on `onyx-1`. The current provider records remain in `VERSIONS.json` as unverified/unavailable evidence, not as usable download sources.

## Provider status

- **Gno.land upstream snapshot service:** [upstream documentation PR #6544](https://github.com/gnolang/gno/pull/6544), merged into `master` on November 27, 2026, identifies `https://snapshots.onyx.testnets.gno.land/` as a source of pruned Onyx database snapshots with SHA-256 metadata. The endpoint, archive layout, chain/height metadata and restore behavior have not been independently verified by Valley. Treat it as a candidate for review, not as an enabled or verified provider. Keep the snapshot helper disabled until those checks and a disposable restore rehearsal are complete.
- **UTSA:** unverified. The available archive path does not provide verifiable Onyx chain identity or checksum metadata.
- **Hazen Network Solutions:** unavailable. No Onyx manifest or archive was found at the known provider path.

## Preserved safety contract

When a chain-specific provider is added, the existing helper contract still requires:

1. a safe per-user `GNOLAND_TESTNET_HOME`;
2. the testnet-scoped `GNOLAND_TESTNET_SERVICE_NAME`;
3. archive download before any service stop;
4. checksum verification when the provider publishes one;
5. archive path validation limited to `db/` and `wal/`;
6. local loopback RPC reporting `onyx-1` with `catching_up=false` before stopping an active service;
7. optional `db`/`wal` backup;
8. rollback state until extraction and restart succeed;
9. preservation of node configuration and secrets.

Do not apply Pearl database state, WAL data, or snapshots to Onyx.
