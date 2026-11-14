#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
fail() { echo "UPGRADE_OVERRIDE_GUARD_FAIL: $*" >&2; exit 1; }

grep -Fq 'check_local_upgrade_overrides "$CONFIG_FILE"' "$DOCTOR" ||
    fail "Node Doctor does not invoke the override check"

# Run the exact read-only helper in isolation; do not query RPC, services or keys.
check_config() {
    {
        printf '%s\n' 'record() { printf "%s|%s|%s\n" "$1" "$2" "$3"; }'
        sed -n '/^check_local_upgrade_overrides() {/,/^}/p' "$DOCTOR"
        printf '%s\n' 'check_local_upgrade_overrides "$1"'
    } | bash -s -- "$1"
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
CFG="$TMP_DIR/config.toml"

cat > "$CFG" <<'EOF_ZERO'
# Root-level default values, including harmless comments.
halt_height = 0 # disabled
skip_upgrade_height = 0
[p2p]
pex = true
EOF_ZERO
[ -z "$(check_config "$CFG")" ] || fail "zero defaults must not warn"

cat > "$CFG" <<'EOF_OVERRIDE'
halt_height = 445000
skip_upgrade_height = 445000
[p2p]
pex = true
EOF_OVERRIDE
result=$(check_config "$CFG")
printf '%s\n' "$result" | grep -Fq 'WARN|local_halt_override|' ||
    fail "nonzero local halt must warn"
printf '%s\n' "$result" | grep -Fq 'WARN|upgrade_gate_bypass|' ||
    fail "nonzero version-gate bypass must warn"

cat > "$CFG" <<'EOF_SECTION'
# A similarly named nested key is not a root-level upgrade override.
halt_height = 0
skip_upgrade_height = 0
[p2p]
halt_height = 123
skip_upgrade_height = 456
EOF_SECTION
[ -z "$(check_config "$CFG")" ] || fail "nested TOML keys must be ignored"

cat > "$CFG" <<'EOF_MALFORMED'
skip_upgrade_height = "not-an-integer"
EOF_MALFORMED
result=$(check_config "$CFG")
printf '%s\n' "$result" | grep -Fq 'WARN|upgrade_gate_bypass|' ||
    fail "unrecognized override must not silently pass"

echo "UPGRADE_OVERRIDE_GUARD_OK"
