# Pearl Snapshots

Snapshot application is available for Gno.land Pearl through the provider paths recorded in `VERSIONS.json` and the pinned `resources/apply_snapshot.sh` runtime helper.

Pearl is a fresh chain. Sapphire database state, WAL data, and snapshots must never be reused on `pearl-1`.

## Current providers

### UTSA

The UTSA path checks that the configured archive is reachable before presenting it to the operator. The current integration does not receive a Pearl chain identifier, block height, or SHA-256 checksum from this provider path, so the tool reports those fields as not provided where applicable.

Treat UTSA as the lower-assurance option: review the displayed provider information and use normal P2P sync if the provenance is not sufficient for your operating policy.

### Hazen Network Solutions

The Hazen path reads the provider index and requires its `chainId` to be exactly `pearl-1`. When present, the helper also surfaces the generated time, block height, archive size, SHA-256 checksum, and provider verification metadata before activation.

If the provider supplies a SHA-256 checksum, the downloaded archive must match it before any database replacement can proceed.

## Activation safeguards

The snapshot helper applies the following safeguards regardless of provider:

1. validates that the selected node home is not `/`, `$HOME`, or the Gno source root;
2. downloads the archive before stopping Gnoland;
3. verifies SHA-256 when the provider publishes one;
4. inspects the archive listing and accepts only `db/` and `wal/` paths, rejecting absolute paths and traversal entries;
5. optionally creates a local backup of the current `db` and `wal` directories;
6. moves the existing database state into a temporary rollback directory before extraction;
7. restores the previous state if extraction or the service restart fails;
8. keeps the existing node configuration and node secrets in place.

Snapshot use remains an operator decision. These safeguards reduce activation risk; they do not turn a third-party snapshot into cryptographic proof of chain history. Normal P2P synchronization through the official Pearl peers remains the fallback when snapshot provenance is not acceptable.
