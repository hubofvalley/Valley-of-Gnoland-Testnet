# Pearl maintenance hardening review notes

This temporary review note records the replacement scope for stale PRs #13, #14, and #15.

- Safe-stop checks use `GNOLAND_TESTNET_SERVICE_NAME` and the RPC port derived from `GNOLAND_TESTNET_HOME/config/config.toml`.
- Unknown/transitional systemd states fail closed; already inactive/failed services do not require a sync-state check.
- Active-service maintenance requires local `pearl-1` with `catching_up=false`.
- The updater fetches, downloads, and verifies all network-dependent artifacts before stopping the service, then re-checks sync state immediately before the maintenance boundary.
- Pearl snapshot support is restored for UTSA and Hazen with testnet-scoped variables, archive path validation, optional backup, rollback, and the same safe-stop gate.
- The launcher pins runtime helpers to reviewed payload commit `d932d2033c84126950fce6c2785e391edf11d005`.

This file can be removed before merge if the PR description is sufficient as the permanent review record.
