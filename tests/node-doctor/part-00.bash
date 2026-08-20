#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOCTOR="$REPO_ROOT/resources/gnoland_node_doctor.sh"
DOCTOR_PART_DIR="$REPO_ROOT/resources/node-doctor"
TEST_ROOT=$(mktemp -d)

cleanup() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "Node Doctor test failed. Preserving diagnostics:" >&2
        find "$TEST_ROOT" -maxdepth 2 -type f \( -name '*.json' -o -name '*.log' \) | while read -r file; do
            echo "--- $file ---" >&2
            tail -n 100 "$file" >&2 || true
        done
    fi
    rm -rf "$TEST_ROOT"
    exit "$exit_code"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_jq() {
    local file=$1 expression=$2
    jq -e "$expression" "$file" >/dev/null || fail "jq assertion failed: $expression ($file)"
}

FIXTURE_HOME="$TEST_ROOT/home"
MOCK_BIN="$TEST_ROOT/mock-bin"
SERVICE_DIR="$TEST_ROOT/systemd"
mkdir -p "$FIXTURE_HOME/gno/.git" \
         "$FIXTURE_HOME/gno/gnoland-data/config" \
         "$FIXTURE_HOME/gno/gnoland-data/secrets" \
         "$FIXTURE_HOME/.config/gno" \
         "$FIXTURE_HOME/go/bin" \
         "$MOCK_BIN" \
         "$SERVICE_DIR"

cat > "$FIXTURE_HOME/go/bin/gnoland" <<'SCRIPT'
#!/bin/bash
if [ "${1:-}" = "version" ]; then
    touch "$HOME/gnoland-version-command-was-executed"
    echo "mock-sapphire"
fi
SCRIPT
cat > "$FIXTURE_HOME/go/bin/gnokey" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
chmod 700 "$FIXTURE_HOME/go/bin/gnoland" "$FIXTURE_HOME/go/bin/gnokey"

printf 'mock sapphire genesis\n' > "$FIXTURE_HOME/gno/genesis.json"
printf '{}\n' > "$FIXTURE_HOME/gno/gnoland-data/secrets/priv_validator_key.json"
printf 'mock keyring\n' > "$FIXTURE_HOME/.config/gno/operator.key"
chmod 700 "$FIXTURE_HOME/gno/gnoland-data/secrets" "$FIXTURE_HOME/.config/gno"
chmod 600 "$FIXTURE_HOME/gno/gnoland-data/secrets/priv_validator_key.json" "$FIXTURE_HOME/.config/gno/operator.key"

EXPECTED_COMMIT="9ab5198acac68016341655c82290ecaff5591edb"
EXPECTED_GNOLAND_SHA="b77b033df80a10bd97d836a2c3eb2b4257279cd7240f21ed6e06b67c7306a434"
EXPECTED_GNOKEY_SHA="f27c7ad0430bdc4a7855af6a6762d202b7d609161f80a8fa223f85882bef486d"
EXPECTED_GENESIS_SHA="d511e0e5b767d4e53f5c1afeeea1bc61d2c7b2118146c820f1f3e4296f67498e"
OS_USER=$(id -un)

cat > "$SERVICE_DIR/gnoland.service" <<EOF_SERVICE
[Unit]
Description=Mock Gno.land Sapphire Node
After=network-online.target

[Service]
User=$OS_USER
WorkingDirectory=$FIXTURE_HOME/gno
Environment=GNOROOT=$FIXTURE_HOME/gno
ExecStart=$FIXTURE_HOME/go/bin/gnoland start --chainid sapphire-1 --genesis genesis.json --skip-genesis-sig-verification --log-level info
Restart=on-failure
LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF_SERVICE

write_healthy_config() {
    cat > "$FIXTURE_HOME/gno/gnoland-data/config/config.toml" <<'EOF_CONFIG'
proxy_app = "tcp://127.0.0.1:26658"
moniker = "doctor-fixture"

[application]
prune_strategy = "syncable"

[mempool]
size = 10000

[p2p]
laddr = "tcp://0.0.0.0:26656"
seeds = ""
persistent_peers = "g10xll77gz6yzg43v9mdalj8360ng6sunt2vvvhf@seed-1.sapphire.testnets.gno.land:26656,g1gw2d7qsmrg06p204ty2qs8ygzd32t2c7p46te0@seed-2.sapphire.testnets.gno.land:26656"
pex = true
flush_throttle_timeout = "10ms"
max_num_outbound_peers = 40

[rpc]
laddr = "tcp://127.0.0.1:26657"

[consensus]
timeout_commit = "3s"
peer_gossip_sleep_duration = "10ms"
EOF_CONFIG
}
write_healthy_config

cat > "$FIXTURE_HOME/.bash_profile" <<EOF_PROFILE
export GNOLAND_SERVICE_NAME="stale-service"
export GNO_SOURCE_DIR="$FIXTURE_HOME/gno"
export GNOLAND_HOME="$FIXTURE_HOME/gno/gnoland-data"
