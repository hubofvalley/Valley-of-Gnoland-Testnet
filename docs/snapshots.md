# Pearl Snapshot Safety

Snapshot application is currently **disabled** for Gno.land Pearl.

Pearl is a fresh chain. The snapshot sources previously integrated into Valley of Gnoland were Sapphire-specific, so those archives must not be applied to `pearl-1`.

## Current behavior

Valley menu option `1c. Apply Snapshot` remains visible for UX continuity, but `resources/apply_snapshot.sh` exits without stopping the service, downloading an archive, or touching node data.

This is intentional fail-closed behavior.

## Why the Sapphire providers are disabled

The previous UTSA/Hazen integration was built for Sapphire. A working URL or archive format is not enough evidence that state belongs to Pearl. Reusing Sapphire db/wal would violate Pearl's fresh-chain model.

## Re-enable criteria

A Pearl snapshot provider can be integrated only after all of the following are reviewed:

1. provider explicitly identifies the snapshot as `pearl-1`;
2. archive layout is validated and restricted to the intended database state;
3. chain/height metadata can be checked before activation;
4. trustworthy checksum or verification metadata is available;
5. rollback behavior is regression-tested;
6. no Sapphire endpoint or chain identifier is accepted by the Pearl path.

Until then, sync through normal P2P using the official Pearl persistent peers.
