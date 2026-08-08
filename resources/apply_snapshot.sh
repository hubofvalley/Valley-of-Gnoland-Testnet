#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

source "$HOME/.bash_profile" 2>/dev/null || true

if [ -z "${GNO_SOURCE_DIR:-}" ]; then
    GNO_SOURCE_DIR="$HOME/gno"
fi
if [ -z "${GNOLAND_HOME:-}" ] || [ "$GNOLAND_HOME" = "$HOME/.gnoland" ] || [ "$GNOLAND_HOME" = "$HOME/gnoland-data" ]; then
    GNOLAND_HOME="$GNO_SOURCE_DIR/gnoland-data"
fi
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}

UTSA_SNAPSHOT_URL="https://share118.utsa.tech/gno_test/gno-test-snapshot.tar.lz4"
HAZEN_INDEX_URL="https://server-9.hazennetworksolutions.com/gnoland-topaz/index.json"
HAZEN_STABLE_URL="https://server-9.hazennetworksolutions.com/gnoland-topaz/gnoland-db-snapshot.tar.lz4"

SNAPSHOT_PROVIDER=""
SNAPSHOT_URL=""
SNAPSHOT_DATE="Not provided by provider"
SNAPSHOT_HEIGHT="Not provided by provider"
SNAPSHOT_SIZE_BYTES=""
SNAPSHOT_SHA256=""
SNAPSHOT_VERIFIED="Not provided by provider"
SNAPSHOT_AVAILABLE=0
STAGING_DIR=""
ROLLBACK_DIR=""
HAD_DB=0
HAD_WAL=0
MOVED_DB=0
MOVED_WAL=0

function cleanup() {
    if [ -n "$STAGING_DIR" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf -- "$STAGING_DIR"
    fi
}

trap cleanup EXIT

function check_dependencies() {
    local missing_packages=()
    command -v curl >/dev/null 2>&1 || missing_packages+=(curl)
    command -v lz4 >/dev/null 2>&1 || missing_packages+=(lz4)
    command -v tar >/dev/null 2>&1 || missing_packages+=(tar)
    command -v python3 >/dev/null 2>&1 || missing_packages+=(python3)

    if [ "${#missing_packages[@]}" -gt 0 ]; then
        echo -e "${YELLOW}Installing required dependencies: ${missing_packages[*]}${NC}"
        sudo apt-get update
        sudo apt-get install -y "${missing_packages[@]}"
    fi
}

function validate_node_home() {
    local resolved_home
    resolved_home=$(readlink -m -- "$GNOLAND_HOME")
    case "$resolved_home" in
        /|"$HOME"|"$GNO_SOURCE_DIR")
            echo -e "${RED}Unsafe GNOLAND_HOME rejected: $resolved_home${NC}"
            return 1
            ;;
    esac
    GNOLAND_HOME="$resolved_home"
}

function reset_snapshot_metadata() {
    SNAPSHOT_PROVIDER=""
    SNAPSHOT_URL=""
    SNAPSHOT_DATE="Not provided by provider"
    SNAPSHOT_HEIGHT="Not provided by provider"
    SNAPSHOT_SIZE_BYTES=""
    SNAPSHOT_SHA256=""
    SNAPSHOT_VERIFIED="Not provided by provider"
    SNAPSHOT_AVAILABLE=0
}

function format_bytes() {
    local bytes=${1:-}
    if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        echo "Not provided by provider"
        return
    fi

    awk -v bytes="$bytes" 'BEGIN {
        split("B KB MB GB TB", unit, " ")
        value = bytes
        unit_index = 1
        while (value >= 1024 && unit_index < 5) {
            value /= 1024
            unit_index++
        }
        if (unit_index == 1) printf "%d %s", value, unit[unit_index]
        else printf "%.2f %s", value, unit[unit_index]
    }'
}

function fetch_http_headers() {
    local url=$1
    curl --silent --show-error --location --head --fail --max-time 20 "$url" 2>/dev/null || return 1
}

function load_utsa_metadata() {
    reset_snapshot_metadata
    SNAPSHOT_PROVIDER="UTSA"
    SNAPSHOT_URL="$UTSA_SNAPSHOT_URL"

    local headers
    if ! headers=$(fetch_http_headers "$SNAPSHOT_URL"); then
        return 1
    fi

    SNAPSHOT_AVAILABLE=1
    SNAPSHOT_DATE=$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1) == "last-modified" {sub(/\r$/, "", $2); value=$2} END {print value}')
    SNAPSHOT_SIZE_BYTES=$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1) == "content-length" {sub(/\r$/, "", $2); value=$2} END {print value}')
    SNAPSHOT_DATE=${SNAPSHOT_DATE:-Not provided by provider}
}

function load_hazen_metadata() {
    reset_snapshot_metadata
    SNAPSHOT_PROVIDER="Hazen Network Solutions"
    SNAPSHOT_URL="$HAZEN_STABLE_URL"

    local index_json
    if index_json=$(curl --silent --show-error --location --fail --max-time 20 "$HAZEN_INDEX_URL" 2>/dev/null); then
        local metadata=()
        mapfile -t metadata < <(python3 -c '
import json, sys
data = json.load(sys.stdin)
if data.get("chainId") != "topaz-1":
    raise SystemExit("unexpected chainId")
for key in ("stableUrl", "url", "generatedAt", "blockHeight", "sizeBytes", "sha256", "verifiedAgainst"):
    value = data.get(key, "")
    print(value if value is not None else "")
' <<<"$index_json" 2>/dev/null) || true

        if [ "${#metadata[@]}" -eq 7 ]; then
            SNAPSHOT_URL=${metadata[0]:-${metadata[1]:-$HAZEN_STABLE_URL}}
            SNAPSHOT_DATE=${metadata[2]:-Not provided by provider}
            SNAPSHOT_HEIGHT=${metadata[3]:-Not provided by provider}
            SNAPSHOT_SIZE_BYTES=${metadata[4]:-}
            SNAPSHOT_SHA256=${metadata[5]:-}
            if [ -n "${metadata[6]}" ]; then
                SNAPSHOT_VERIFIED="Yes (${metadata[6]})"
            fi
        fi
    fi

    if fetch_http_headers "$SNAPSHOT_URL" >/dev/null; then
        SNAPSHOT_AVAILABLE=1
        return 0
    fi

    SNAPSHOT_URL="$HAZEN_STABLE_URL"
    if fetch_http_headers "$SNAPSHOT_URL" >/dev/null; then
        SNAPSHOT_AVAILABLE=1
        return 0
    fi

    return 1
}

function show_snapshot_stats() {
    local status
    if [ "$SNAPSHOT_AVAILABLE" -eq 1 ]; then
        status="${GREEN}Available${NC}"
    else
        status="${RED}Not available at the moment${NC}"
    fi

    echo -e "${GREEN}${SNAPSHOT_PROVIDER}${NC}"
    echo -e "  Status          : $status"
    echo "  Created/Updated : $SNAPSHOT_DATE"
    echo "  Snapshot Height : $SNAPSHOT_HEIGHT"
    echo "  Size            : $(format_bytes "$SNAPSHOT_SIZE_BYTES")"
    echo "  AppHash Verified: $SNAPSHOT_VERIFIED"
}

function show_menu() {
    echo -e "${GREEN}Choose a snapshot provider:${NC}"
    echo "1. UTSA"
    echo "2. Hazen Network Solutions"
    echo "3. Exit"
}

function ask_database_backup() {
    echo -e "${YELLOW}Applying a snapshot will replace the current db and wal folders.${NC}"
    read -r -p "Backup current db and wal first? (y/n): " backup_choice
    case "${backup_choice,,}" in
        y|yes) return 0 ;;
        n|no) return 1 ;;
        *)
            echo -e "${RED}Invalid choice. Snapshot application cancelled.${NC}"
            exit 1
            ;;
    esac
}

function backup_current_database() {
    local backup_items=()
    local backup_file
    backup_file="$HOME/gnoland-db-wal-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    [ -d "$GNOLAND_HOME/db" ] && backup_items+=(db)
    [ -d "$GNOLAND_HOME/wal" ] && backup_items+=(wal)
    if [ "${#backup_items[@]}" -eq 0 ]; then
        echo -e "${YELLOW}No db or wal folders found to backup.${NC}"
        return 0
    fi

    echo -e "${GREEN}Backing up current database...${NC}"
    tar -czf "$backup_file" -C "$GNOLAND_HOME" "${backup_items[@]}" || return 1
    chmod 600 "$backup_file" || return 1
    echo -e "${GREEN}Backup saved to:${NC} $backup_file"
}

function verify_snapshot_archive() {
    local archive=$1

    if [ -n "$SNAPSHOT_SHA256" ]; then
        echo -e "${GREEN}Verifying SHA-256 checksum...${NC}"
        printf '%s  %s\n' "$SNAPSHOT_SHA256" "$archive" | sha256sum --check --status
    else
        echo -e "${YELLOW}Provider does not publish a checksum; checksum verification skipped.${NC}"
    fi

    echo -e "${GREEN}Validating snapshot archive paths...${NC}"
    local archive_listing="$STAGING_DIR/archive-contents.txt"
    lz4 -d -c "$archive" | tar -tf - >"$archive_listing"

    awk '
        BEGIN { found_db=0; found_wal=0 }
        {
            path=$0
            sub(/^\.\//, "", path)
            if (path == "db" || path ~ /^db\//) found_db=1
            else if (path == "wal" || path ~ /^wal\//) found_wal=1
            else exit 1
            if (path ~ /(^|\/)\.\.($|\/)/ || path ~ /^\//) exit 1
        }
        END { if (!found_db || !found_wal) exit 1 }
    ' "$archive_listing"
}

function stop_gnoland() {
    echo -e "${GREEN}Stopping Gnoland service...${NC}"
    sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || pkill -f "gnoland start" 2>/dev/null || true
}

function start_gnoland() {
    echo -e "${GREEN}Restarting Gnoland service...${NC}"
    sudo systemctl restart "$GNOLAND_SERVICE_NAME"
    local attempts=0
    while [ "$attempts" -lt 3 ]; do
        attempts=$((attempts + 1))
        sleep 3
        sudo systemctl is-active --quiet "$GNOLAND_SERVICE_NAME" || return 1
    done
}

function rollback_database() {
    echo -e "${RED}Snapshot activation failed; restoring the previous db and wal.${NC}"
    if [ "$MOVED_DB" -eq 1 ]; then
        rm -rf -- "$GNOLAND_HOME/db"
        mv "$ROLLBACK_DIR/db" "$GNOLAND_HOME/db"
    elif [ "$HAD_DB" -eq 0 ]; then
        rm -rf -- "$GNOLAND_HOME/db"
    fi
    if [ "$MOVED_WAL" -eq 1 ]; then
        rm -rf -- "$GNOLAND_HOME/wal"
        mv "$ROLLBACK_DIR/wal" "$GNOLAND_HOME/wal"
    elif [ "$HAD_WAL" -eq 0 ]; then
        rm -rf -- "$GNOLAND_HOME/wal"
    fi
    sudo systemctl restart "$GNOLAND_SERVICE_NAME" || true
}

function activate_snapshot() {
    local archive=$1
    local should_backup=$2

    stop_gnoland
    if [ "$should_backup" -eq 1 ]; then
        if ! backup_current_database; then
            echo -e "${RED}Database backup failed; restarting Gnoland without applying the snapshot.${NC}"
            sudo systemctl restart "$GNOLAND_SERVICE_NAME" || true
            return 1
        fi
    fi

    ROLLBACK_DIR="$GNOLAND_HOME/.vog-snapshot-rollback-$(date +%Y%m%d-%H%M%S)"
    if ! mkdir -p "$ROLLBACK_DIR"; then
        sudo systemctl restart "$GNOLAND_SERVICE_NAME" || true
        return 1
    fi
    [ -d "$GNOLAND_HOME/db" ] && HAD_DB=1
    [ -d "$GNOLAND_HOME/wal" ] && HAD_WAL=1
    if [ "$HAD_DB" -eq 1 ]; then
        if ! mv "$GNOLAND_HOME/db" "$ROLLBACK_DIR/db"; then
            rollback_database
            return 1
        fi
        MOVED_DB=1
    fi
    if [ "$HAD_WAL" -eq 1 ]; then
        if ! mv "$GNOLAND_HOME/wal" "$ROLLBACK_DIR/wal"; then
            rollback_database
            return 1
        fi
        MOVED_WAL=1
    fi

    echo -e "${GREEN}Extracting the verified snapshot...${NC}"
    if ! lz4 -d -c "$archive" | tar -xf - -C "$GNOLAND_HOME"; then
        rollback_database
        return 1
    fi

    if ! start_gnoland; then
        rollback_database
        return 1
    fi

    rm -rf -- "$ROLLBACK_DIR"
    ROLLBACK_DIR=""
}

function apply_snapshot() {
    local loader=$1
    if ! "$loader"; then
        show_snapshot_stats
        echo -e "${RED}Snapshot application cancelled because the provider is unavailable.${NC}"
        exit 1
    fi

    show_snapshot_stats
    echo -e "Grand Valley extends its gratitude to ${YELLOW}$SNAPSHOT_PROVIDER${NC} for providing snapshot support."
    echo -e "${YELLOW}Config and node secrets are kept in place.${NC}"
    read -r -p "Apply this snapshot now? Type yes to continue: " confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo -e "${RED}Snapshot application cancelled.${NC}"
        exit 0
    fi

    local should_backup=0
    if ask_database_backup; then
        should_backup=1
    fi

    check_dependencies
    mkdir -p "$(dirname "$GNOLAND_HOME")"
    STAGING_DIR=$(mktemp -d "$(dirname "$GNOLAND_HOME")/.vog-snapshot-download.XXXXXX")
    local archive="$STAGING_DIR/snapshot.tar.lz4"

    echo -e "${GREEN}Downloading snapshot before stopping Gnoland...${NC}"
    curl --fail --location --retry 3 --retry-delay 5 --continue-at - --output "$archive" "$SNAPSHOT_URL"
    verify_snapshot_archive "$archive"
    activate_snapshot "$archive" "$should_backup"

    echo -e "${GREEN}Snapshot setup completed successfully.${NC}"
    echo -e "${YELLOW}Showing live logs. Press Ctrl+C to stop following logs.${NC}"
    sudo journalctl -u "$GNOLAND_SERVICE_NAME" -f -o cat
}

function main() {
    check_dependencies
    validate_node_home
    show_menu
    read -r -p "Enter your choice: " provider_choice

    case "$provider_choice" in
        1) apply_snapshot load_utsa_metadata ;;
        2) apply_snapshot load_hazen_metadata ;;
        3) echo -e "${GREEN}Exiting.${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid choice. Exiting.${NC}"; exit 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
