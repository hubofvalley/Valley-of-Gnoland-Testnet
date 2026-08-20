#!/bin/bash

set -u -o pipefail

DOCTOR_VERSION="1.0.0"
EXPECTED_CHAIN_ID="sapphire-1"
EXPECTED_RELEASE_COMMIT="9ab5198acac68016341655c82290ecaff5591edb"
EXPECTED_GENESIS_SHA256="d511e0e5b767d4e53f5c1afeeea1bc61d2c7b2118146c820f1f3e4296f67498e"
EXPECTED_GNOLAND_SHA256="b77b033df80a10bd97d836a2c3eb2b4257279cd7240f21ed6e06b67c7306a434"
EXPECTED_GNOKEY_SHA256="f27c7ad0430bdc4a7855af6a6762d202b7d609161f80a8fa223f85882bef486d"
EXPECTED_SOURCE_REMOTE="https://github.com/gnolang/gno.git"
EXPECTED_PERSISTENT_PEERS="g10xll77gz6yzg43v9mdalj8360ng6sunt2vvvhf@seed-1.sapphire.testnets.gno.land:26656,g1gw2d7qsmrg06p204ty2qs8ygzd32t2c7p46te0@seed-2.sapphire.testnets.gno.land:26656"
WARN_BLOCK_LAG="${GNOLAND_DOCTOR_WARN_BLOCK_LAG:-20}"
FAIL_BLOCK_LAG="${GNOLAND_DOCTOR_FAIL_BLOCK_LAG:-200}"
WARN_BLOCK_AGE_SECONDS="${GNOLAND_DOCTOR_WARN_BLOCK_AGE_SECONDS:-60}"
FAIL_BLOCK_AGE_SECONDS="${GNOLAND_DOCTOR_FAIL_BLOCK_AGE_SECONDS:-300}"
WARN_DISK_PERCENT="${GNOLAND_DOCTOR_WARN_DISK_PERCENT:-85}"
FAIL_DISK_PERCENT="${GNOLAND_DOCTOR_FAIL_DISK_PERCENT:-95}"
WARN_FREE_DISK_GIB="${GNOLAND_DOCTOR_WARN_FREE_DISK_GIB:-50}"
FAIL_FREE_DISK_GIB="${GNOLAND_DOCTOR_FAIL_FREE_DISK_GIB:-20}"
MIN_RAM_PASS_KIB="${GNOLAND_DOCTOR_MIN_RAM_PASS_KIB:-15728640}"
MIN_RAM_WARN_KIB="${GNOLAND_DOCTOR_MIN_RAM_WARN_KIB:-8388608}"

INVALID_THRESHOLD_OVERRIDES=()
normalise_uint_setting() {
    local name=$1 default_value=$2 value=${!1}
    if [[ "$value" =~ ^[0-9]{1,9}$ ]]; then
        return
    fi
    INVALID_THRESHOLD_OVERRIDES+=("${name}=${value}")
    printf -v "$name" '%s' "$default_value"
}

normalise_uint_setting WARN_BLOCK_LAG 20
normalise_uint_setting FAIL_BLOCK_LAG 200
normalise_uint_setting WARN_BLOCK_AGE_SECONDS 60
normalise_uint_setting FAIL_BLOCK_AGE_SECONDS 300
normalise_uint_setting WARN_DISK_PERCENT 85
normalise_uint_setting FAIL_DISK_PERCENT 95
normalise_uint_setting WARN_FREE_DISK_GIB 50
normalise_uint_setting FAIL_FREE_DISK_GIB 20
normalise_uint_setting MIN_RAM_PASS_KIB 15728640
normalise_uint_setting MIN_RAM_WARN_KIB 8388608

if [ "$FAIL_BLOCK_LAG" -le "$WARN_BLOCK_LAG" ]; then
    INVALID_THRESHOLD_OVERRIDES+=("block_lag_order=${WARN_BLOCK_LAG}/${FAIL_BLOCK_LAG}")
    WARN_BLOCK_LAG=20
    FAIL_BLOCK_LAG=200
fi
if [ "$FAIL_BLOCK_AGE_SECONDS" -le "$WARN_BLOCK_AGE_SECONDS" ]; then
    INVALID_THRESHOLD_OVERRIDES+=("block_age_order=${WARN_BLOCK_AGE_SECONDS}/${FAIL_BLOCK_AGE_SECONDS}")
    WARN_BLOCK_AGE_SECONDS=60
    FAIL_BLOCK_AGE_SECONDS=300
fi
if [ "$FAIL_DISK_PERCENT" -le "$WARN_DISK_PERCENT" ]; then
    INVALID_THRESHOLD_OVERRIDES+=("disk_percent_order=${WARN_DISK_PERCENT}/${FAIL_DISK_PERCENT}")
    WARN_DISK_PERCENT=85
    FAIL_DISK_PERCENT=95
fi
if [ "$FAIL_FREE_DISK_GIB" -ge "$WARN_FREE_DISK_GIB" ]; then
    INVALID_THRESHOLD_OVERRIDES+=("free_disk_order=${WARN_FREE_DISK_GIB}/${FAIL_FREE_DISK_GIB}")
    WARN_FREE_DISK_GIB=50
    FAIL_FREE_DISK_GIB=20
fi
if [ "$MIN_RAM_PASS_KIB" -le "$MIN_RAM_WARN_KIB" ]; then
    INVALID_THRESHOLD_OVERRIDES+=("memory_order=${MIN_RAM_WARN_KIB}/${MIN_RAM_PASS_KIB}")
    MIN_RAM_PASS_KIB=15728640
    MIN_RAM_WARN_KIB=8388608
fi

JSON_MODE=false
STRICT_MODE=false
OFFLINE_MODE=false

usage() {
    cat <<'USAGE'
Usage: gnoland_node_doctor.sh [options]

Read-only health and configuration-drift inspection for Valley of Gnoland.
The doctor never changes config, restarts services, or modifies keys.

Options:
  --json       Emit machine-readable JSON only.
  --strict     Return a non-zero exit code when warnings are present.
  --offline    Skip public Sapphire RPC checks.
  --version    Print the doctor version.
  -h, --help   Show this help.

Exit codes:
  0  No failures (and no warnings when --strict is used).
  1  One or more failures, or warnings under --strict.
  2  Invalid command-line arguments.
USAGE
}

