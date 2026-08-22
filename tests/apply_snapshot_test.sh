#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SNAPSHOT_SCRIPT="$ROOT_DIR/resources/apply_snapshot.sh"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local haystack=$1 needle=$2
    [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_file() {
    [ -f "$1" ] || fail "expected file: $1"
}

[ -f "$SNAPSHOT_SCRIPT" ] || fail "snapshot script missing"

grep -Fq 'UTSA_SNAPSHOT_URL="https://share118.utsa.tech/gno_test/gno-test-snapshot.tar.lz4"' "$SNAPSHOT_SCRIPT" || fail "UTSA URL drifted"
grep -Fq 'HAZEN_INDEX_URL="https://server-9.hazennetworksolutions.com/gnoland-sapphire/index.json"' "$SNAPSHOT_SCRIPT" || fail "Hazen manifest URL drifted"
grep -Fq 'HAZEN_STABLE_URL="https://server-9.hazennetworksolutions.com/gnoland-db-snapshot.tar.lz4"' "$SNAPSHOT_SCRIPT" || fail "Hazen stable URL drifted"
grep -Fq 'data.get("chainId") != "sapphire-1"' "$SNAPSHOT_SCRIPT" || fail "Hazen Sapphire chain guard missing"
if grep -Eq 'topaz-1|gnoland-topaz' "$SNAPSHOT_SCRIPT"; then
    fail "Topaz runtime reference remains in snapshot helper"
fi

menu_output=$(
    HOME="$TEST_TMP/menu-home" GNO_SOURCE_DIR="$TEST_TMP/menu-home/gno" GNOLAND_HOME="$TEST_TMP/menu-home/gno/gnoland-data" \
        bash -c 'mkdir -p "$HOME"; source "$1"; show_menu' _ "$SNAPSHOT_SCRIPT"
)
assert_contains "$menu_output" '1. UTSA'
assert_contains "$menu_output" '2. Hazen Network Solutions'
assert_contains "$menu_output" '3. Exit'

HOME="$TEST_TMP/hazen-good-home" GNO_SOURCE_DIR="$TEST_TMP/hazen-good-home/gno" GNOLAND_HOME="$TEST_TMP/hazen-good-home/gno/gnoland-data" \
SNAPSHOT_SCRIPT="$SNAPSHOT_SCRIPT" bash <<'EOS'
set -euo pipefail
mkdir -p "$HOME"
source "$SNAPSHOT_SCRIPT"
curl() {
    if [[ "$*" == *"$HAZEN_INDEX_URL"* ]] && [[ "$*" != *"--head"* ]]; then
        printf '%s\n' '{"chainId":"sapphire-1","stableUrl":"https://snapshot.example/sapphire.tar.lz4","generatedAt":"2026-08-19T03:18:50Z","blockHeight":265198,"sizeBytes":5916315648,"sha256":"abc123","verifiedAgainst":"apphash"}'
        return 0
    fi
    if [[ "$*" == *"--head"* ]]; then
        printf 'HTTP/1.1 200 OK\r\nContent-Length: 5916315648\r\n'
        return 0
    fi
    return 1
}
load_hazen_metadata
[ "$SNAPSHOT_AVAILABLE" -eq 1 ]
[ "$SNAPSHOT_HEIGHT" = "265198" ]
[ "$SNAPSHOT_URL" = "https://snapshot.example/sapphire.tar.lz4" ]
EOS

HOME="$TEST_TMP/hazen-bad-home" GNO_SOURCE_DIR="$TEST_TMP/hazen-bad-home/gno" GNOLAND_HOME="$TEST_TMP/hazen-bad-home/gno/gnoland-data" \
SNAPSHOT_SCRIPT="$SNAPSHOT_SCRIPT" bash <<'EOS'
set -euo pipefail
mkdir -p "$HOME"
source "$SNAPSHOT_SCRIPT"
curl() {
    if [[ "$*" == *"$HAZEN_INDEX_URL"* ]] && [[ "$*" != *"--head"* ]]; then
        printf '%s\n' '{"chainId":"topaz-1","stableUrl":"https://snapshot.example/topaz.tar.lz4"}'
        return 0
    fi
    if [[ "$*" == *"--head"* ]]; then
        return 0
    fi
    return 1
}
if load_hazen_metadata; then
    exit 1
fi
[ "$SNAPSHOT_AVAILABLE" -eq 0 ]
EOS

for mode in cancel unavailable; do
    case_home="$TEST_TMP/$mode-home"
    mkdir -p "$case_home/gno/gnoland-data/db" "$case_home/gno/gnoland-data/wal"
    printf 'old-db\n' >"$case_home/gno/gnoland-data/db/marker"
    printf 'old-wal\n' >"$case_home/gno/gnoland-data/wal/marker"
    if [ "$mode" = "cancel" ]; then
        HOME="$case_home" GNO_SOURCE_DIR="$case_home/gno" GNOLAND_HOME="$case_home/gno/gnoland-data" SNAPSHOT_SCRIPT="$SNAPSHOT_SCRIPT" \
            bash -c 'source "$SNAPSHOT_SCRIPT"; loader(){ reset_snapshot_metadata; SNAPSHOT_PROVIDER=UTSA; SNAPSHOT_URL="$UTSA_SNAPSHOT_URL"; SNAPSHOT_AVAILABLE=1; }; printf "no\n" | apply_snapshot loader' >/dev/null
    else
        if HOME="$case_home" GNO_SOURCE_DIR="$case_home/gno" GNOLAND_HOME="$case_home/gno/gnoland-data" SNAPSHOT_SCRIPT="$SNAPSHOT_SCRIPT" \
            bash -c 'source "$SNAPSHOT_SCRIPT"; loader(){ reset_snapshot_metadata; SNAPSHOT_PROVIDER=UTSA; return 1; }; apply_snapshot loader' >/dev/null 2>&1; then
            fail "unavailable provider unexpectedly succeeded"
        fi
    fi
    assert_file "$case_home/gno/gnoland-data/db/marker"
    assert_file "$case_home/gno/gnoland-data/wal/marker"
done

HOME="$TEST_TMP/archive-home" GNO_SOURCE_DIR="$TEST_TMP/archive-home/gno" GNOLAND_HOME="$TEST_TMP/archive-home/gno/gnoland-data" \
SNAPSHOT_SCRIPT="$SNAPSHOT_SCRIPT" bash <<'EOS'
set -euo pipefail
mkdir -p "$HOME" "$GNOLAND_HOME"
source "$SNAPSHOT_SCRIPT"
STAGING_DIR=$(mktemp -d)
SNAPSHOT_SHA256=""
lz4() { cat "${@: -1}"; }
tar() {
    if [ "${1:-}" = "-tf" ]; then
        cat
        return 0
    fi
    command tar "$@"
}
printf 'db/\ndb/state\nwal/\nwal/log\n' >"$STAGING_DIR/valid"
verify_snapshot_archive "$STAGING_DIR/valid" >/dev/null
printf 'db/\nwal/\nsecrets/validator_key\n' >"$STAGING_DIR/extra"
if verify_snapshot_archive "$STAGING_DIR/extra" >/dev/null 2>&1; then
    exit 1
fi
printf 'db/\nwal/\ndb/../secrets/key\n' >"$STAGING_DIR/traversal"
if verify_snapshot_archive "$STAGING_DIR/traversal" >/dev/null 2>&1; then
    exit 1
fi
EOS

HOME="$TEST_TMP/activate-home" GNO_SOURCE_DIR="$TEST_TMP/activate-home/gno" GNOLAND_HOME="$TEST_TMP/activate-home/gno/gnoland-data" \
SNAPSHOT_SCRIPT="$SNAPSHOT_SCRIPT" bash <<'EOS'
set -euo pipefail
mkdir -p "$HOME" "$GNOLAND_HOME/db" "$GNOLAND_HOME/wal"
printf old >"$GNOLAND_HOME/db/marker"
printf old >"$GNOLAND_HOME/wal/marker"
source "$SNAPSHOT_SCRIPT"
stop_gnoland() { :; }
start_gnoland() { return 0; }
lz4() { cat "${@: -1}"; }
tar() {
    if [ "${1:-}" = "-xf" ]; then
        local dest=""
        while [ "$#" -gt 0 ]; do
            if [ "$1" = "-C" ]; then
                dest=$2
                break
            fi
            shift
        done
        mkdir -p "$dest/db" "$dest/wal"
        printf new >"$dest/db/marker"
        printf new >"$dest/wal/marker"
        cat >/dev/null
        return 0
    fi
    command tar "$@"
}
archive="$HOME/fake-archive"
printf archive >"$archive"
activate_snapshot "$archive" 0 >/dev/null
[ "$(cat "$GNOLAND_HOME/db/marker")" = new ]
[ "$(cat "$GNOLAND_HOME/wal/marker")" = new ]
[ -z "$ROLLBACK_DIR" ]
if find "$GNOLAND_HOME" -maxdepth 1 -name '.vog-snapshot-rollback-*' | grep -q .; then
    exit 1
fi
EOS

HOME="$TEST_TMP/rollback-home" GNO_SOURCE_DIR="$TEST_TMP/rollback-home/gno" GNOLAND_HOME="$TEST_TMP/rollback-home/gno/gnoland-data" \
SNAPSHOT_SCRIPT="$SNAPSHOT_SCRIPT" bash <<'EOS'
set -euo pipefail
mkdir -p "$HOME" "$GNOLAND_HOME/db" "$GNOLAND_HOME/wal"
printf old-db >"$GNOLAND_HOME/db/marker"
printf old-wal >"$GNOLAND_HOME/wal/marker"
source "$SNAPSHOT_SCRIPT"
stop_gnoland() { :; }
sudo() { return 0; }
lz4() { cat "${@: -1}"; }
tar() {
    if [ "${1:-}" = "-xf" ]; then
        cat >/dev/null
        return 1
    fi
    command tar "$@"
}
archive="$HOME/fake-archive"
printf archive >"$archive"
if activate_snapshot "$archive" 0 >/dev/null 2>&1; then
    exit 1
fi
[ "$(cat "$GNOLAND_HOME/db/marker")" = old-db ]
[ "$(cat "$GNOLAND_HOME/wal/marker")" = old-wal ]
EOS

echo "PASS: snapshot regression tests"
