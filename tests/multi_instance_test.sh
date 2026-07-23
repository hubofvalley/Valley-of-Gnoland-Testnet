#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
cleanup() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "Multi-instance test failed. Recent fixture logs:" >&2
        for log in "$TEST_ROOT"/*.log; do
            [ -f "$log" ] || continue
            echo "--- $(basename "$log") ---" >&2
            tail -n 80 "$log" >&2
        done
    fi
    rm -rf "$TEST_ROOT"
    exit "$exit_code"
}
trap cleanup EXIT

MOCK_BIN="$TEST_ROOT/mock-bin"
FIXTURES="$TEST_ROOT/fixtures"
SYSTEMD_DIR="$TEST_ROOT/systemd"
mkdir -p "$MOCK_BIN" "$FIXTURES" "$SYSTEMD_DIR"

cat > "$MOCK_BIN/sudo" <<'EOF'
#!/bin/bash
case "${1:-}" in
    apt|apt-get|ufw) exit 0 ;;
esac
exec "$@"
EOF

cat > "$MOCK_BIN/systemctl" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "show" ]; then
    unit=${2%.service}
    file="$MOCK_SYSTEMD_DIR/${unit}.service"
    [ -f "$file" ] && printf '%s\n' "$file"
    exit 0
fi
case "${1:-}" in
    is-active) exit 0 ;;
    *) exit 0 ;;
esac
EOF

cat > "$MOCK_BIN/git" <<'EOF'
#!/bin/bash
case " $* " in
    *" rev-parse HEAD "*) printf '%s\n' "fc40526511474e40b8a66419f5ba28255085bc08" ;;
    *" remote get-url origin "*) printf '%s\n' "https://github.com/gnolang/gno.git" ;;
esac
exit 0
EOF

cat > "$MOCK_BIN/sha256sum" <<'EOF'
#!/bin/bash
cat >/dev/null
exit 0
EOF

cat > "$MOCK_BIN/ss" <<'EOF'
#!/bin/bash
for port in ${MOCK_OCCUPIED_PORTS:-}; do
    case " $* " in
        *":${port} "*) printf 'LISTEN 0 10 127.0.0.1:%s\n' "$port" ;;
    esac
done
EOF

cat > "$MOCK_BIN/curl" <<'EOF'
#!/bin/bash
out=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) out=$2; shift 2 ;;
        http://127.0.0.1:*/status)
            printf '%s\n' '{"result":{"node_info":{"network":"topaz-1"},"sync_info":{"latest_block_height":"1","catching_up":false}}}'
            exit 0
            ;;
        http*|https*) url=$1; shift ;;
        *) shift ;;
    esac
done
case "$url" in
    *gnoland_linux_amd64) cp "$MOCK_FIXTURES/gnoland" "$out" ;;
    *gnokey_linux_amd64) cp "$MOCK_FIXTURES/gnokey" "$out" ;;
    *genesis.json) printf 'mock genesis\n' > "$out" ;;
    *) exit 1 ;;
esac
EOF

cat > "$FIXTURES/gnoland" <<'EOF'
#!/bin/bash
set -e
case "${1:-}" in
    version) echo "mock-topaz" ;;
    config)
        case "${2:-}" in
            init)
                mkdir -p "$GNOROOT/gnoland-data/config"
                cat > "$GNOROOT/gnoland-data/config/config.toml" <<'CONFIG'
proxy_app = "tcp://127.0.0.1:26658"
[p2p]
laddr = "tcp://0.0.0.0:26656"
seeds = ""
persistent_peers = ""
[rpc]
laddr = "tcp://127.0.0.1:26657"
CONFIG
                ;;
            set)
                key=$3
                value=$4
                cfg="$GNOROOT/gnoland-data/config/config.toml"
                case "$key" in
                    proxy_app) sed -i "s|^proxy_app = .*|proxy_app = \"$value\"|" "$cfg" ;;
                    p2p.laddr)
                        sed -i "/^\\[p2p\\]/,/^\\[/ s|^laddr = .*|laddr = \"$value\"|" "$cfg"
                        ;;
                    rpc.laddr)
                        sed -i "/^\\[rpc\\]/,/^\\[/ s|^laddr = .*|laddr = \"$value\"|" "$cfg"
                        ;;
                    p2p.seeds) sed -i "s|^seeds = .*|seeds = \"$value\"|" "$cfg" ;;
                    p2p.persistent_peers)
                        sed -i "s|^persistent_peers = .*|persistent_peers = \"$value\"|" "$cfg"
                        ;;
                esac
                ;;
        esac
        ;;
    secrets)
        case "${2:-}" in
            init)
                mkdir -p "$GNOROOT/gnoland-data/secrets"
                printf '{}\n' > "$GNOROOT/gnoland-data/secrets/priv_validator_key.json"
                ;;
            get) echo "gpub1mockconsensus" ;;
        esac
        ;;
esac
EOF

cat > "$FIXTURES/gnokey" <<'EOF'
#!/bin/bash
case " $* " in
    *" list "*) echo "0. operator (local) - addr: g1mock" ;;
    *) exit 0 ;;
esac
EOF

chmod +x "$MOCK_BIN"/* "$FIXTURES"/*

make_installer() {
    local output=$1
    cp "$REPO_ROOT/resources/gnoland_node_install_testnet.sh" "$output"
    sed -i "s|/etc/systemd/system/|$SYSTEMD_DIR/|g" "$output"
}

prepare_home() {
    local home=$1
    mkdir -p "$home/gno/.git" "$home/gno/gnovm/stdlibs/errors" "$home/.config/gno"
    : > "$home/.bash_profile"
}

run_install() {
    local home=$1 service=$2 prefix=$3 log=$4
    local installer="$TEST_ROOT/${service}-installer.sh"
    make_installer "$installer"
    printf 'node-%s\n%s\n\np\nn\n1\nMIGRATE-TO-TOPAZ\noperator\n' "$service" "$prefix" |
        env -u SUDO_USER \
            HOME="$home" \
            PATH="$MOCK_BIN:/usr/bin:/bin" \
            MOCK_FIXTURES="$FIXTURES" \
            MOCK_SYSTEMD_DIR="$SYSTEMD_DIR" \
            GNOLAND_SERVICE_NAME="$service" \
            GNO_SOURCE_DIR="$home/gno" \
            GNOLAND_HOME="$home/gno/gnoland-data" \
            GNOKEY_HOME="$home/.config/gno" \
            GNOROOT="$home/gno" \
            GNOLAND_BIN="$home/go/bin/gnoland" \
            GNOKEY_BIN="$home/go/bin/gnokey" \
            bash "$installer" >"$log" 2>&1
}

HOME_A="$TEST_ROOT/home-a"
HOME_B="$TEST_ROOT/home-b"
prepare_home "$HOME_A"
prepare_home "$HOME_B"

run_install "$HOME_A" gnoland 26 "$TEST_ROOT/a.log"
HASH_A=$(sha256sum "$HOME_A/go/bin/gnoland" | awk '{print $1}')
run_install "$HOME_B" gnoland-topaz 36 "$TEST_ROOT/b.log"

test -x "$HOME_A/go/bin/gnoland"
test -x "$HOME_B/go/bin/gnoland"
test "$HASH_A" = "$(sha256sum "$HOME_A/go/bin/gnoland" | awk '{print $1}')"
grep -q "^User=$(id -un)$" "$SYSTEMD_DIR/gnoland.service"
grep -q "^WorkingDirectory=$HOME_A/gno$" "$SYSTEMD_DIR/gnoland.service"
grep -q "^WorkingDirectory=$HOME_B/gno$" "$SYSTEMD_DIR/gnoland-topaz.service"
grep -q 'proxy_app = "tcp://127.0.0.1:36658"' "$HOME_B/gno/gnoland-data/config/config.toml"
grep -q 'laddr = "tcp://0.0.0.0:36656"' "$HOME_B/gno/gnoland-data/config/config.toml"
grep -q 'laddr = "tcp://127.0.0.1:36657"' "$HOME_B/gno/gnoland-data/config/config.toml"
grep -q "Topaz Gnoland service started successfully" "$TEST_ROOT/a.log"
grep -q "Topaz Gnoland service started successfully" "$TEST_ROOT/b.log"

env -u SUDO_USER \
    HOME="$HOME_B" \
    PATH="$MOCK_BIN:/usr/bin:/bin" \
    MOCK_FIXTURES="$FIXTURES" \
    MOCK_SYSTEMD_DIR="$SYSTEMD_DIR" \
    bash "$REPO_ROOT/resources/gnoland_update.sh" >"$TEST_ROOT/update-b.log" 2>&1
test "$HASH_A" = "$(sha256sum "$HOME_A/go/bin/gnoland" | awk '{print $1}')"
grep -q "export GNO_SOURCE_DIR=\"$HOME_B/gno\"" "$HOME_B/.bash_profile"

cat > "$SYSTEMD_DIR/shared.service" <<EOF
[Service]
User=another-user
WorkingDirectory=$HOME_A/gno
EOF
make_installer "$TEST_ROOT/collision-installer.sh"
set +e
printf 'collision\n46\n\np\nn\n' |
    env -u SUDO_USER \
        HOME="$HOME_B" \
        PATH="$MOCK_BIN:/usr/bin:/bin" \
        MOCK_FIXTURES="$FIXTURES" \
        MOCK_SYSTEMD_DIR="$SYSTEMD_DIR" \
        GNOLAND_SERVICE_NAME=shared \
        GNO_SOURCE_DIR="$HOME_B/gno" \
        GNOLAND_HOME="$HOME_B/gno/gnoland-data" \
        GNOKEY_HOME="$HOME_B/.config/gno" \
        GNOROOT="$HOME_B/gno" \
        GNOLAND_BIN="$HOME_B/go/bin/gnoland" \
        GNOKEY_BIN="$HOME_B/go/bin/gnokey" \
        bash "$TEST_ROOT/collision-installer.sh" >"$TEST_ROOT/collision.log" 2>&1
COLLISION_RC=$?
set -e
test "$COLLISION_RC" -ne 0
grep -q "belongs to another instance" "$TEST_ROOT/collision.log"
test -x "$HOME_A/go/bin/gnoland"

HOME_C="$TEST_ROOT/home-c"
prepare_home "$HOME_C"
make_installer "$TEST_ROOT/port-installer.sh"
printf 'port-test\n71\n46\n\np\nn\n47\n1\nMIGRATE-TO-TOPAZ\noperator\n' |
    env -u SUDO_USER \
        HOME="$HOME_C" \
        PATH="$MOCK_BIN:/usr/bin:/bin" \
        MOCK_FIXTURES="$FIXTURES" \
        MOCK_SYSTEMD_DIR="$SYSTEMD_DIR" \
        MOCK_OCCUPIED_PORTS=46656 \
        GNOLAND_SERVICE_NAME=port-test \
        GNO_SOURCE_DIR="$HOME_C/gno" \
        GNOLAND_HOME="$HOME_C/gno/gnoland-data" \
        GNOKEY_HOME="$HOME_C/.config/gno" \
        GNOROOT="$HOME_C/gno" \
        GNOLAND_BIN="$HOME_C/go/bin/gnoland" \
        GNOKEY_BIN="$HOME_C/go/bin/gnokey" \
        bash "$TEST_ROOT/port-installer.sh" >"$TEST_ROOT/port.log" 2>&1
grep -q "two digits from 01 through 64" "$TEST_ROOT/port.log"
grep -q "conflicts with a running listener" "$TEST_ROOT/port.log"
grep -q 'laddr = "tcp://0.0.0.0:47656"' "$HOME_C/gno/gnoland-data/config/config.toml"

if rg -n '/usr/local/bin/(gnoland|gnokey)' "$REPO_ROOT/resources"; then
    echo "Runtime scripts still manage global Gnoland command links." >&2
    exit 1
fi

echo "MULTI_INSTANCE_TEST_OK"
