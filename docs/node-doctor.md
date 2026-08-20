# Valley of Gnoland Node Doctor

Node Doctor is a read-only health and configuration-drift inspector for a Gno.land Sapphire node managed by Valley of Gnoland.

The Node Doctor script does not edit `config.toml`, restart or stop systemd services, change firewall rules, download binaries, execute the inspected `gnoland`/`gnokey` binaries, or touch operator and consensus keys. The `doctor` command mode dispatches before the main Valley of Gnoland profile handling, then parses only simple managed `export NAME=value` assignments without sourcing or executing arbitrary profile commands. A failed check is a diagnosis, not an automatic repair action.

The interactive `1g` menu entry runs the same inspection after Valley of Gnoland's normal interactive initialisation. Use command mode when the entire launch path must remain strictly read-only.

## Run

From the main Valley of Gnoland entry point:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor
```

Machine-readable JSON output:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --json
```

Skip comparison with the public Sapphire RPC:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --offline
```

Treat warnings as a non-zero result for automation:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/valleyofGnoland.sh) doctor --json --strict
```

The interactive menu exposes the same checks under `1g. Run Node Doctor`; direct command mode is the strict read-only entry point.

## Status meanings

| Status | Meaning |
|---|---|
| `PASS` | The observed state matches the managed Sapphire baseline or an advised safety threshold. |
| `WARN` | The state is usable but needs operator review, or an optional check could not run. |
| `FAIL` | A chain-critical, security-sensitive, or operational requirement is missing or has drifted. |

Node Doctor exits with code `0` when no failures exist. It exits with code `1` when one or more failures exist. With `--strict`, warnings also produce exit code `1`. Invalid command-line options return exit code `2`.

## Checks

### Runtime and instance identity

- The command is run as the node operating-system user rather than through `sudo`.
- Only the Valley of Gnoland environment exports needed for inspection are parsed from `.bash_profile`; other profile lines are ignored and never executed.
- Explicit environment variables override matching profile exports, which makes one-off inspection of a selected instance possible without editing the profile.
- The configured systemd service name is valid.
- Managed source, data, keyring, genesis, and binary paths remain under the current user's home directory.
- Required and optional inspection commands are available.

### Systemd service

- The selected service exists and is readable.
- `User=` and `WorkingDirectory=` belong to the selected instance.
- `ExecStart=` uses the managed `gnoland` binary, `sapphire-1`, genesis-signature bypass required by Sapphire, and `--log-level info`.
- `Environment=GNOROOT` matches the selected instance source directory.
- Restart policy and open-file limits match the Valley of Gnoland baseline.
- The service is active.

### Release artefacts

- The Gno source checkout is pinned to the managed Sapphire commit.
- The source remote points to the official `gnolang/gno` repository.
- Official prebuilt `gnoland` and `gnokey` checksums match. A locally built binary is reported as a warning when the source commit is correctly pinned because locally compiled binaries are not byte-for-byte reproducible.
- The Sapphire genesis checksum matches exactly.
- The shell resolves `gnoland` to the managed per-user binary.

### Configuration drift

Chain-critical values are compared against the Sapphire baseline:

```text
application.prune_strategy = syncable
consensus.timeout_commit = 3s
consensus.peer_gossip_sleep_duration = 10ms
p2p.flush_throttle_timeout = 10ms
```

The doctor also reviews:

- advised mempool and outbound-peer values;
- empty `p2p.seeds`, peer exchange, and valid persistent peers;
- loopback-only RPC and ABCI bindings;
- configured P2P listener;
- distinct ABCI, P2P, and RPC ports;
- consistency with `GNOLAND_PORT` when a port prefix is exported.

A drift result includes a suggested command, but Node Doctor never executes it. Review every change before applying it, especially on an active validator.

### Live node health

- Local RPC response and reported chain ID.
- `catching_up` state.
- Age of the latest local block.
- Connected peer count.
- Chain ID and height reported by the public comparison RPC.
- Difference between local height and the public Sapphire RPC height.
- Live RPC and P2P TCP listeners.
- Detection of a wildcard-bound public RPC listener.
- Read-only UFW status and detection of an explicit RPC allow rule when UFW is readable.

Default alert thresholds can be overridden for monitoring environments. Invalid, excessively large, or inverted WARN/FAIL values are ignored, reported as a warning, and replaced with the safe defaults so JSON output and arithmetic checks remain reliable:

```bash
export GNOLAND_DOCTOR_WARN_BLOCK_LAG=20
export GNOLAND_DOCTOR_FAIL_BLOCK_LAG=200
export GNOLAND_DOCTOR_WARN_BLOCK_AGE_SECONDS=60
export GNOLAND_DOCTOR_FAIL_BLOCK_AGE_SECONDS=300
```

### Hardware and host safety

- At least four virtual CPUs are recommended.
- Current Gno operator guidance requires at least 16 GiB RAM.
- Disk utilisation and remaining capacity are checked.
- Non-rotational storage is detected when `findmnt` and `lsblk` can resolve the backing device. Local NVMe is recommended for validator operation.
- NTP clock synchronisation is checked through `timedatectl`.

Disk thresholds can be adjusted:

```bash
export GNOLAND_DOCTOR_WARN_DISK_PERCENT=85
export GNOLAND_DOCTOR_FAIL_DISK_PERCENT=95
export GNOLAND_DOCTOR_WARN_FREE_DISK_GIB=50
export GNOLAND_DOCTOR_FAIL_FREE_DISK_GIB=20
```

### Secret permissions

The doctor checks the node secrets directory and operator keyring for group or world access. It reports unsafe modes but does not run `chmod` automatically because ownership and key layouts must be reviewed by the operator first.

## JSON schema

The JSON document contains:

- schema and doctor versions;
- generation time;
- selected instance paths;
- one structured object per check;
- PASS, WARN, and FAIL totals;
- overall status and intended process exit code.

Example:

```json
{
  "schema_version": "1.0",
  "doctor_version": "1.0.0",
  "read_only": true,
  "instance": {
    "service": "gnoland.service",
    "expected_chain_id": "sapphire-1"
  },
  "checks": [
    {
      "category": "config",
      "id": "timeout_commit",
      "status": "PASS",
      "message": "Configuration matches Sapphire",
      "detail": "consensus.timeout_commit=3s",
      "remediation": ""
    }
  ],
  "summary": {
    "pass": 1,
    "warn": 0,
    "fail": 0,
    "overall": "PASS",
    "exit_code": 0
  }
}
```

## Validator safety

A doctor report can identify a problem, but it cannot determine the safest maintenance window. Before changing config, stopping a service, replacing binaries, restoring keys, or moving validator data, test the procedure on a non-validator or non-production node whenever possible.
