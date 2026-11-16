# Valley of Gnoland Onyx Node Doctor

Node Doctor is a read-only health and configuration-drift inspector for a Gno.land Onyx node managed by Valley of Gnoland.

It does not edit configuration, restart services, change firewall rules, replace binaries, or touch operator/consensus keys.

## Run

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor
```

JSON output:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --json
```

Treat warnings as non-zero as well:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --strict
```

## Onyx checks

The doctor checks:

- per-user `gnoland` and `gnokey` executables;
- source checkout commit `5cdbc25fcde0b7569911a4e308ae5d2f6e96c399`;
- Onyx genesis SHA-256 `4b006fd7ccdec052865accc84dd29b2b76f8b57b2560789a15eedaa88f0e26c5`;
- official Onyx persistent peers;
- `application.prune_strategy = syncable`;
- `consensus.timeout_commit = 3s`;
- `consensus.peer_gossip_sleep_duration = 10ms`;
- `p2p.flush_throttle_timeout = 10ms`;
- PEX enabled;
- systemd starts `onyx-1`;
- systemd ownership and explicit `--data-dir` match `GNOLAND_TESTNET_HOME`;
- required `--skip-genesis-sig-verification` startup flag;
- local RPC reports `onyx-1`;
- public Onyx RPC reachability/network;
- NTP synchronization when available;
- basic free-disk safety signal.

## Active consensus and P2P settings

Node Doctor verifies one active, quoted `consensus.timeout_commit = "3s"`,
`consensus.peer_gossip_sleep_duration = "10ms"`, and
`p2p.flush_throttle_timeout = "10ms"` value in the expected TOML table.
A commented example, matching setting in another table, duplicate declaration,
missing value, or unsupported syntax cannot produce a false PASS.
The required timing settings retain FAIL on drift; `p2p.pex` is checked as
an active TOML boolean and retains WARN when disabled or unverified.

This is a read-only check of standard single-line `config.toml` values, not
a complete TOML parser or proof of live node state. It does not reconfigure
the validator. A download-only launcher with an older immutable helper pin
does not automatically receive this change; distribution needs separate review.

## Exit codes

- `0`: no FAIL results; in normal mode WARN is allowed.
- `1`: one or more FAIL results, or any WARN when `--strict` is used.
- `2`: invalid command-line/runtime-ref input.

The report is diagnostic only. Review any remediation before changing an active validator.
