# Valley of Gnoland Pearl Node Doctor

Node Doctor is a read-only health and configuration-drift inspector for a Gno.land Pearl node managed by Valley of Gnoland.

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

## Pearl checks

The doctor checks:

- per-user `gnoland` and `gnokey` executables;
- source checkout commit `c4c72fdd288c757e8da0d93aae867fa479b1b15c`;
- Pearl genesis SHA-256 `c45fe60c8c8a1f859d9e4d5aad7ce4d100ff0eb78302e71318ba0de481a8dc91`;
- official Pearl persistent peers;
- `application.prune_strategy = syncable`;
- `consensus.timeout_commit = 3s`;
- `consensus.peer_gossip_sleep_duration = 10ms`;
- `p2p.flush_throttle_timeout = 10ms`;
- PEX enabled;
- systemd starts `pearl-1`;
- required `--skip-genesis-sig-verification` startup flag;
- local RPC reports `pearl-1`;
- public Pearl RPC reachability/network;
- NTP synchronization when available;
- basic free-disk safety signal.

## Exit codes

- `0`: no FAIL results; in normal mode WARN is allowed.
- `1`: one or more FAIL results, or any WARN when `--strict` is used.
- `2`: invalid command-line/runtime-ref input.

The report is diagnostic only. Review any remediation before changing an active validator.
