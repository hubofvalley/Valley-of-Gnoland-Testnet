export GNOLAND_GENESIS="$FIXTURE_HOME/gno/genesis.json"
export GNOKEY_HOME="$FIXTURE_HOME/.config/gno"
export GNOROOT="$FIXTURE_HOME/gno"
export GNOLAND_BIN="$FIXTURE_HOME/go/bin/gnoland"
export GNOKEY_BIN="$FIXTURE_HOME/go/bin/gnokey"
export GNOLAND_SERVICE_NAME="gnoland"
export GNOLAND_PORT="26"
export GNOLAND_PUBLIC_REMOTE="https://rpc.sapphire.testnets.gno.land"
export PATH="$FIXTURE_HOME/go/bin:$MOCK_BIN:/usr/bin:/bin"
# The doctor must never execute arbitrary profile commands.
touch "\$HOME/profile-side-effect"
printf 'PROFILE_NOISE_MUST_NOT_APPEAR\n'
EOF_PROFILE

cat > "$MOCK_BIN/systemctl" <<EOF_SYSTEMCTL
#!/bin/bash
case "\${1:-}" in
    show)
        if [ "\${3:-}" = "-p" ] && [ "\${4:-}" = "FragmentPath" ]; then
            printf '%s\n' "$SERVICE_DIR/gnoland.service"
        fi
        ;;
    is-active)
        echo active
        ;;
    *)
        exit 0
        ;;
esac
EOF_SYSTEMCTL

cat > "$MOCK_BIN/git" <<EOF_GIT
#!/bin/bash
case " \$* " in
    *" rev-parse HEAD "*) echo "$EXPECTED_COMMIT" ;;
    *" remote get-url origin "*) echo "https://github.com/gnolang/gno.git" ;;
    *) exit 0 ;;
esac
EOF_GIT

cat > "$MOCK_BIN/curl" <<'EOF_CURL'
#!/bin/bash
url="${*: -1}"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
network=${MOCK_LOCAL_NETWORK:-sapphire-1}
public_network=${MOCK_PUBLIC_NETWORK:-sapphire-1}
case "$url" in
    http://127.0.0.1:26657/status)
        printf '{"result":{"node_info":{"network":"%s"},"sync_info":{"latest_block_height":"1000","catching_up":false,"latest_block_time":"%s"}}}\n' "$network" "$now"
        ;;
    http://127.0.0.1:26657/net_info)
        printf '%s\n' '{"result":{"n_peers":"8"}}'
        ;;
    https://rpc.sapphire.testnets.gno.land/status)
        printf '{"result":{"node_info":{"network":"%s"},"sync_info":{"latest_block_height":"1001"}}}\n' "$public_network"
        ;;
    *)
        exit 22
        ;;
esac
EOF_CURL

cat > "$MOCK_BIN/sha256sum" <<EOF_SHA256SUM
#!/bin/bash
last=""
for arg in "\$@"; do
    [ "\$arg" = "--" ] && continue
    last=\$arg
done
case "\$last" in
    "$FIXTURE_HOME/go/bin/gnoland") printf '%s  %s\n' "$EXPECTED_GNOLAND_SHA" "\$last" ;;
    "$FIXTURE_HOME/go/bin/gnokey") printf '%s  %s\n' "$EXPECTED_GNOKEY_SHA" "\$last" ;;
    "$FIXTURE_HOME/gno/genesis.json") printf '%s  %s\n' "$EXPECTED_GENESIS_SHA" "\$last" ;;
    *) exec /usr/bin/sha256sum "\$@" ;;
esac
EOF_SHA256SUM

cat > "$MOCK_BIN/ss" <<'EOF_SS'
#!/bin/bash
case " $* " in
    *":26657"*) echo "LISTEN 0 4096 127.0.0.1:26657 0.0.0.0:*" ;;
    *":26656"*) echo "LISTEN 0 4096 0.0.0.0:26656 0.0.0.0:*" ;;
    *) exit 0 ;;
esac
EOF_SS

cat > "$MOCK_BIN/timedatectl" <<'EOF_TIMEDATECTL'
#!/bin/bash
echo yes
EOF_TIMEDATECTL

cat > "$MOCK_BIN/ufw" <<'EOF_UFW'
#!/bin/bash
cat <<'STATUS'
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
26656/tcp                  ALLOW       Anywhere
STATUS
if [ "${MOCK_UFW_ALLOW_RPC:-0}" = "1" ]; then
    echo "26657/tcp                  ALLOW       Anywhere"
fi
EOF_UFW

cat > "$MOCK_BIN/findmnt" <<'EOF_FINDMNT'
#!/bin/bash
echo /dev/mock0
EOF_FINDMNT

cat > "$MOCK_BIN/lsblk" <<'EOF_LSBLK'
#!/bin/bash
echo 0
EOF_LSBLK

cat > "$MOCK_BIN/nproc" <<'EOF_NPROC'
#!/bin/bash
echo 8
EOF_NPROC

chmod +x "$MOCK_BIN"/*

common_env=(
    env
    -u SUDO_USER
    HOME="$FIXTURE_HOME"
    PATH="$FIXTURE_HOME/go/bin:$MOCK_BIN:/usr/bin:/bin"
    GNOLAND_DOCTOR_WARN_FREE_DISK_GIB=1
    GNOLAND_DOCTOR_MEM_TOTAL_KIB=33554432
    GNOLAND_DOCTOR_FAIL_FREE_DISK_GIB=0
)
