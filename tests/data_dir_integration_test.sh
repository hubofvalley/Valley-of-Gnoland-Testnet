#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="$ROOT/resources/gnoland_node_install_testnet.sh"
MAIN="$ROOT/resources/valleyofGnoland.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
SNAPSHOT="$ROOT/resources/apply_snapshot.sh"
DOCTOR="$ROOT/resources/gnoland_node_doctor.sh"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/vog-data-dir.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() { echo "DATA_DIR_INTEGRATION_FAIL: $*" >&2; exit 1; }
assert_file() { [ -f "$1" ] || fail "expected file: $1"; }
assert_missing() { [ ! -e "$1" ] || fail "unexpected path: $1"; }

HOME_ROOT="$TEST_ROOT/home"
SOURCE_ROOT="$HOME_ROOT/gno"
DEFAULT_HOME="$SOURCE_ROOT/gnoland-data"
CUSTOM_HOME="$HOME_ROOT/custom-pearl-data"
OUTSIDE_ROOT="$TEST_ROOT/outside"
mkdir -p "$HOME_ROOT" "$SOURCE_ROOT/.git" "$DEFAULT_HOME" "$CUSTOM_HOME" "$OUTSIDE_ROOT"
: >"$HOME_ROOT/.bash_profile"

# The installer must reject a home/root target before it can remove any state.
installer_marker="$HOME_ROOT/installer-marker"
printf 'keep\n' >"$installer_marker"
if HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" GNOLAND_TESTNET_HOME="$HOME_ROOT" \
    GNOLAND_GENESIS="$SOURCE_ROOT/genesis.json" bash "$INSTALLER" </dev/null >/dev/null 2>&1; then
    fail "installer accepted HOME as the node data directory"
fi
[ "$(cat "$installer_marker")" = keep ] || fail "installer changed state before rejecting unsafe target"

# A custom home is the only target used by backup and delete. The default path
# is populated as a tripwire for accidental fallback.
mkdir -p "$CUSTOM_HOME/secrets" "$DEFAULT_HOME/secrets"
printf 'custom-secret\n' >"$CUSTOM_HOME/secrets/marker"
printf 'default-secret\n' >"$DEFAULT_HOME/secrets/marker"
HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" GNOLAND_TESTNET_HOME="$CUSTOM_HOME" \
    GNOLAND_GENESIS="$SOURCE_ROOT/genesis.json" GNOROOT="$SOURCE_ROOT" GNOKEY_HOME="$HOME_ROOT/.config/gno" \
    GNOLAND_BIN="$HOME_ROOT/go/bin/gnoland" GNOKEY_BIN="$HOME_ROOT/go/bin/gnokey" \
    GNOLAND_TESTNET_SERVICE_NAME=custom-pearl bash -c '
        source "$1"
        menu() { :; }
        systemctl() { return 1; }
        backup_node_secrets
    ' _ "$MAIN" >/dev/null
backup_archive=$(find "$HOME_ROOT" -maxdepth 1 -type f -name 'gnoland-secrets-backup-*.tar.gz' -print -quit)
[ -n "$backup_archive" ] || fail "backup did not create an archive"
tar -tzf "$backup_archive" | grep -Fq 'secrets/marker' || fail "backup did not read custom data directory"
[ "$(cat "$DEFAULT_HOME/secrets/marker")" = default-secret ] || fail "backup touched default data directory"

# Delete requires the explicit confirmation token and removes only the selected
# custom data directory. Default data remains a mutation tripwire.
mkdir -p "$CUSTOM_HOME/db" "$DEFAULT_HOME/db" "$HOME_ROOT/go/bin"
printf 'custom-db\n' >"$CUSTOM_HOME/db/marker"
printf 'default-db\n' >"$DEFAULT_HOME/db/marker"
printf 'genesis\n' >"$SOURCE_ROOT/genesis.json"
printf 'binary\n' >"$HOME_ROOT/go/bin/gnoland"
printf 'key-binary\n' >"$HOME_ROOT/go/bin/gnokey"
HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" GNOLAND_TESTNET_HOME="$CUSTOM_HOME" \
    GNOLAND_GENESIS="$SOURCE_ROOT/genesis.json" GNOROOT="$SOURCE_ROOT" GNOKEY_HOME="$HOME_ROOT/.config/gno" \
    GNOLAND_TESTNET_SERVICE_NAME=custom-pearl \
    GNOLAND_BIN="$HOME_ROOT/go/bin/gnoland" GNOKEY_BIN="$HOME_ROOT/go/bin/gnokey" bash -c '
        source "$1"
        menu() { :; }
        prompt_back_or_continue() { return 0; }
        systemctl() { return 0; }
        sudo() { return 0; }
        printf "no\\n" | delete_gnoland_node
    ' _ "$MAIN" >/dev/null
assert_file "$CUSTOM_HOME/db/marker"
# A missing service identity must block even an otherwise valid delete token.
HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" GNOLAND_TESTNET_HOME="$CUSTOM_HOME" \
    GNOLAND_GENESIS="$SOURCE_ROOT/genesis.json" GNOROOT="$SOURCE_ROOT" GNOKEY_HOME="$HOME_ROOT/.config/gno" \
    GNOLAND_TESTNET_SERVICE_NAME=custom-pearl GNOLAND_BIN="$HOME_ROOT/go/bin/gnoland" \
    GNOKEY_BIN="$HOME_ROOT/go/bin/gnokey" bash -c '
        source "$1"
        menu() { :; }
        prompt_back_or_continue() { return 0; }
        systemctl() { return 0; }
        sudo() { return 0; }
        printf "DELETE-PEARL-NODE\\n" | delete_gnoland_node
    ' _ "$MAIN" >/dev/null 2>&1
assert_file "$CUSTOM_HOME/db/marker"

DELETE_SERVICE="$TEST_ROOT/delete.service"
cat >"$DELETE_SERVICE" <<EOF_SERVICE
[Service]
User=$(id -un)
WorkingDirectory=$SOURCE_ROOT
ExecStart=$HOME_ROOT/go/bin/gnoland start --data-dir $CUSTOM_HOME --chainid pearl-1 --skip-genesis-sig-verification
EOF_SERVICE
HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" GNOLAND_TESTNET_HOME="$CUSTOM_HOME" \
    GNOLAND_GENESIS="$SOURCE_ROOT/genesis.json" GNOROOT="$SOURCE_ROOT" GNOKEY_HOME="$HOME_ROOT/.config/gno" \
    GNOLAND_TESTNET_SERVICE_NAME=custom-pearl GNOLAND_BIN="$HOME_ROOT/go/bin/gnoland" \
    GNOKEY_BIN="$HOME_ROOT/go/bin/gnokey" MOCK_SERVICE_FILE="$DELETE_SERVICE" bash -c '
        source "$1"
        menu() { :; }
        prompt_back_or_continue() { return 0; }
        systemctl() {
            if [ "${1:-}" = show ]; then
                printf "%s\\n" "$MOCK_SERVICE_FILE"
            fi
            return 0
        }
        sudo() { return 0; }
        printf "DELETE-PEARL-NODE\\n" | delete_gnoland_node
    ' _ "$MAIN" >/dev/null
assert_missing "$CUSTOM_HOME"
assert_file "$DEFAULT_HOME/db/marker"
[ "$(cat "$DEFAULT_HOME/db/marker")" = default-db ] || fail "delete touched default data directory"

# Updater target identity is checked before any stop or network work. A unit
# pointing at another in-home directory is a RED mutation case.
UPDATER_MOCK="$TEST_ROOT/updater-mock"
mkdir -p "$UPDATER_MOCK"
cat >"$UPDATER_MOCK/systemctl" <<'SCRIPT'
#!/bin/bash
if [ "${1:-}" = show ]; then
    printf '%s\n' "$MOCK_SERVICE_FILE"
fi
exit 0
SCRIPT
chmod +x "$UPDATER_MOCK/systemctl"
UPDATER_SERVICE="$TEST_ROOT/updater.service"
cat >"$UPDATER_SERVICE" <<EOF_SERVICE
[Service]
User=$(id -un)
WorkingDirectory=$SOURCE_ROOT
ExecStart=$HOME_ROOT/go/bin/gnoland start --data-dir $OUTSIDE_ROOT --chainid pearl-1 --skip-genesis-sig-verification
EOF_SERVICE
if PATH="$UPDATER_MOCK:/usr/bin:/bin" HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" \
    GNOLAND_TESTNET_HOME="$CUSTOM_HOME" GNOLAND_TESTNET_SERVICE_NAME=custom-pearl \
    GNOLAND_BIN="$HOME_ROOT/go/bin/gnoland" GNOKEY_BIN="$HOME_ROOT/go/bin/gnokey" \
    MOCK_SERVICE_FILE="$UPDATER_SERVICE" bash "$UPDATER" >/dev/null 2>&1; then
    fail "updater accepted a service targeting another data directory"
fi
[ -d "$OUTSIDE_ROOT" ] || fail "updater changed or removed the outside target"

# Snapshot must fail closed for inactive and failed services when the unit
# identity is not proven. The stop hook is a RED mutation tripwire.
for state in inactive failed; do
    SNAPSHOT_SERVICE="$TEST_ROOT/snapshot-$state.service"
    cat >"$SNAPSHOT_SERVICE" <<EOF_SERVICE
[Service]
User=$(id -un)
WorkingDirectory=$SOURCE_ROOT
ExecStart=$HOME_ROOT/go/bin/gnoland start --data-dir $OUTSIDE_ROOT --chainid pearl-1 --skip-genesis-sig-verification
EOF_SERVICE
    if HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" GNOLAND_TESTNET_HOME="$CUSTOM_HOME" \
        GNOLAND_TESTNET_SERVICE_NAME=custom-pearl MOCK_SERVICE_FILE="$SNAPSHOT_SERVICE" \
        SNAPSHOT_STATE="$state" bash -c '
            source "$1"
            systemctl() {
                case "${1:-}" in
                    show) printf "%s\\n" "$MOCK_SERVICE_FILE" ;;
                    is-active) printf "%s\\n" "$SNAPSHOT_STATE"; return 3 ;;
                    *) return 1 ;;
                esac
            }
            stop_gnoland() { : >"$HOME/stop-was-called"; }
            safe_stop_preflight
        ' _ "$SNAPSHOT" >/dev/null 2>&1; then
        fail "snapshot accepted an unproven $state service target"
    fi
    assert_missing "$HOME_ROOT/stop-was-called"
done

# A valid custom target can activate a disposable archive without touching the
# default directory. This is sandbox-only and never invokes a real node.
mkdir -p "$CUSTOM_HOME/db" "$CUSTOM_HOME/wal"
printf 'old-custom\n' >"$CUSTOM_HOME/db/marker"
printf 'default-live\n' >"$DEFAULT_HOME/marker"
VALID_SERVICE="$TEST_ROOT/valid-snapshot.service"
cat >"$VALID_SERVICE" <<EOF_SERVICE
[Service]
User=$(id -un)
WorkingDirectory=$SOURCE_ROOT
ExecStart=$HOME_ROOT/go/bin/gnoland start --data-dir $CUSTOM_HOME --chainid pearl-1 --skip-genesis-sig-verification
EOF_SERVICE
HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" GNOLAND_TESTNET_HOME="$CUSTOM_HOME" \
    GNOLAND_TESTNET_SERVICE_NAME=custom-pearl MOCK_SERVICE_FILE="$VALID_SERVICE" bash -c '
        source "$1"
        systemctl() { if [ "${1:-}" = show ]; then printf "%s\\n" "$MOCK_SERVICE_FILE"; else return 1; fi; }
        stop_gnoland() { :; }
        start_gnoland() { return 0; }
        lz4() { cat "${@: -1}"; }
        tar() {
            if [ "${1:-}" = -xf ]; then
                local destination=""
                while [ "$#" -gt 0 ]; do
                    if [ "$1" = -C ]; then destination=$2; break; fi
                    shift
                done
                mkdir -p "$destination/db" "$destination/wal"
                printf "new-custom\\n" >"$destination/db/marker"
                printf "new-custom\\n" >"$destination/wal/marker"
                cat >/dev/null
                return 0
            fi
            command tar "$@"
        }
        archive="$HOME/archive"
        printf archive >"$archive"
        activate_snapshot "$archive" 0
    ' _ "$SNAPSHOT" >/dev/null
[ "$(cat "$CUSTOM_HOME/db/marker")" = new-custom ] || fail "snapshot did not write custom data directory"
[ "$(cat "$DEFAULT_HOME/marker")" = default-live ] || fail "snapshot touched default data directory"

# Node Doctor reports the same custom home and verifies the unit data-dir.
DOCTOR_SERVICE="$TEST_ROOT/doctor.service"
cat >"$DOCTOR_SERVICE" <<EOF_SERVICE
[Service]
User=$(id -un)
WorkingDirectory=$SOURCE_ROOT
ExecStart=$HOME_ROOT/go/bin/gnoland start --data-dir $CUSTOM_HOME --chainid pearl-1 --skip-genesis-sig-verification
EOF_SERVICE
mkdir -p "$HOME_ROOT/go/bin" "$CUSTOM_HOME/config"
printf 'genesis\n' >"$SOURCE_ROOT/genesis.json"
cat >"$HOME_ROOT/go/bin/gnoland" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
cat >"$HOME_ROOT/go/bin/gnokey" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
chmod +x "$HOME_ROOT/go/bin/gnoland" "$HOME_ROOT/go/bin/gnokey"
DOCTOR_MOCK="$TEST_ROOT/doctor-mock"
mkdir -p "$DOCTOR_MOCK"
cat >"$DOCTOR_MOCK/systemctl" <<'SCRIPT'
#!/bin/bash
if [ "${1:-}" = show ]; then
    printf '%s\n' "$MOCK_SERVICE_FILE"
fi
exit 0
SCRIPT
cat >"$DOCTOR_MOCK/curl" <<'SCRIPT'
#!/bin/bash
printf '%s\n' '{"result":{"node_info":{"network":"pearl-1"}}}'
SCRIPT
chmod +x "$DOCTOR_MOCK/systemctl" "$DOCTOR_MOCK/curl"
doctor_json=$(PATH="$DOCTOR_MOCK:/usr/bin:/bin" HOME="$HOME_ROOT" GNO_SOURCE_DIR="$SOURCE_ROOT" \
    GNOLAND_TESTNET_HOME="$CUSTOM_HOME" GNOLAND_TESTNET_SERVICE_NAME=custom-pearl \
    GNOLAND_GENESIS="$SOURCE_ROOT/genesis.json" GNOLAND_BIN="$HOME_ROOT/go/bin/gnoland" \
    GNOKEY_BIN="$HOME_ROOT/go/bin/gnokey" GNOLAND_REMOTE=http://127.0.0.1:26657 \
    GNOLAND_PUBLIC_REMOTE=http://127.0.0.1:26657 MOCK_SERVICE_FILE="$DOCTOR_SERVICE" \
    bash "$DOCTOR" --json 2>/dev/null || true)
printf '%s\n' "$doctor_json" | jq -e --arg home "$CUSTOM_HOME" '
    .results as $results
    | .node_home == $home
    and any($results[]; .code == "service_data_dir" and .level == "PASS")
' >/dev/null || fail "Node Doctor did not verify the custom data directory"

# Source-level contracts keep future edits from removing the explicit wiring.
grep -Fq 'config init -config-path "$CONFIG_FILE" -force' "$INSTALLER" || fail "installer config path contract missing"
grep -Fq 'secrets init -data-dir "$SECRETS_DIR" -force' "$INSTALLER" || fail "installer secrets path contract missing"
grep -Fq -- '--data-dir $GNOLAND_TESTNET_HOME' "$INSTALLER" || fail "systemd data-dir contract missing"
grep -Fq 'service_data_dir' "$UPDATER" || fail "updater identity guard missing"
grep -Fq 'service_data_dir' "$SNAPSHOT" || fail "snapshot identity guard missing"
grep -Fq 'service_data_dir' "$DOCTOR" || fail "doctor identity check missing"

echo "DATA_DIR_INTEGRATION_OK"
