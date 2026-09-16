# Pearl Snapshots

Snapshot application is available for Gno.land Pearl through the provider paths recorded in `VERSIONS.json`. The helper uses `GNOLAND_TESTNET_HOME` and `GNOLAND_TESTNET_SERVICE_NAME`, defaulting to `~/gno/gnoland-data` and `gnoland-testnet.service`.

Pearl is a fresh chain. Sapphire database state, WAL data, and snapshots must never be reused on `pearl-1`.

## Current providers

### UTSA

The UTSA path checks that the configured archive is reachable before presenting it to the operator. The current integration does not receive a Pearl chain identifier, block height, or SHA-256 checksum from this provider path.

Treat UTSA as the lower-assurance option: review the displayed provider information and use normal P2P sync if the provenance is not sufficient for your operating policy.

### Hazen Network Solutions

The Hazen path reads the provider index and requires its `chainId` to be exactly `pearl-1`. When present, the helper also surfaces the generated time, block height, archive size, SHA-256 checksum, and provider verification metadata before activation.

If the provider publishes a SHA-256 checksum, the downloaded archive must match it before any database replacement can proceed.

## Activation safeguards

The snapshot helper applies the following safeguards:

1. validates that `GNOLAND_TESTNET_HOME` is a safe per-user path and not `/`, `$HOME`, or the Gno source root;
2. uses the testnet-scoped `GNOLAND_TESTNET_SERVICE_NAME` rather than the mainnet service name;
3. downloads the archive before stopping Gnoland;
4. verifies SHA-256 when the provider publishes one;
5. inspects the archive and accepts only `db/` and `wal/` paths, rejecting absolute paths and traversal entries;
6. before stopping an active service, requires a local loopback RPC to report `pearl-1` with `catching_up=false`;
7. optionally creates a local backup of the current `db` and `wal` directories;
8. moves the existing database state into a temporary rollback directory before extraction;
9. restores the previous state if extraction or the service restart fails;
10. keeps the existing node configuration and node secrets in place.

The pinned Pearl release predates upstream crash-safety fix `gnolang/gno#6085`, so maintenance fails closed if the local service state, chain identity, or sync state cannot be verified. An inactive or already-failed service does not require a sync-state check because the helper is not causing the stop.

Snapshot use remains an operator decision. These safeguards reduce activation risk; they do not turn a third-party snapshot into cryptographic proof of chain history. Normal P2P synchronization through the official Pearl peers remains the fallback when snapshot provenance is not acceptable.
