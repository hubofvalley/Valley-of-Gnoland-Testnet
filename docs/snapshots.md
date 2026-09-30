# Onyx Snapshots

Onyx snapshot support is currently unavailable. The menu option remains visible for UX compatibility, but `resources/apply_snapshot.sh` fails closed because no chain-specific provider, chain identity, and checksum have been verified. Use normal P2P synchronization through the official Onyx peers.

Onyx is a fresh chain. Pearl database state, WAL data, and snapshots must never be reused on `onyx-1`. The current provider records remain in `VERSIONS.json` as unverified/unavailable evidence, not as usable download sources.

## Provider status

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
