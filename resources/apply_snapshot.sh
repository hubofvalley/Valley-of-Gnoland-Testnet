#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

source "$HOME/.bash_profile" 2>/dev/null || true

if [ -z "${GNO_SOURCE_DIR:-}" ] || [ "$GNO_SOURCE_DIR" = "$HOME/gno-src-test13" ]; then
    GNO_SOURCE_DIR="$HOME/gno"
fi
if [ -z "${GNOLAND_HOME:-}" ] || [ "$GNOLAND_HOME" = "$HOME/.gnoland" ] || [ "$GNOLAND_HOME" = "$HOME/gnoland-data" ]; then
    GNOLAND_HOME="$GNO_SOURCE_DIR/gnoland-data"
fi
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
UTSA_SNAPSHOT_URL="https://share118.utsa.tech/gno_test13/gno-test13-snapshot.tar.lz4"

function prompt_back_or_continue() {
    read -r -p "Press Enter to continue or type 'back' to go back to the menu: " user_choice
    if [[ ${user_choice,,} == "back" ]]; then
        exit 0
    fi
}

function check_dependencies() {
    local missing=()
    for bin in curl lz4 tar; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            missing+=("$bin")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo -e "${YELLOW}Installing required dependencies: ${missing[*]}${NC}"
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    fi
}

function show_menu() {
    echo -e "${GREEN}Choose a snapshot provider:${NC}"
    echo "1. UTSA"
    echo "2. Exit"
}

function check_url() {
    local url=$1
    if curl --output /dev/null --silent --head --fail "$url"; then
        echo -e "${GREEN}Available${NC}"
    else
        echo -e "${RED}Not available at the moment${NC}"
        return 1
    fi
}

function apply_utsa_snapshot() {
    provider_name="UTSA"
    echo -e "${GREEN}UTSA snapshot selected.${NC}"
    echo -e "Grand Valley extends its gratitude to ${YELLOW}$provider_name${NC} for providing snapshot support."
    echo -e "${GREEN}Checking availability of UTSA snapshot:${NC}"
    echo -n "Gno.land Test13 Snapshot: "
    check_url "$UTSA_SNAPSHOT_URL"

    prompt_back_or_continue

    echo -e "${YELLOW}This will stop Gnoland and replace the old chain database folders only.${NC}"
    echo -e "${YELLOW}Config and node secrets are kept in place.${NC}"
    read -r -p "Apply UTSA snapshot now? Type yes to continue: " confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo -e "${RED}Snapshot application cancelled.${NC}"
        exit 0
    fi

    check_dependencies

    echo -e "${GREEN}Stopping Gnoland service...${NC}"
    sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || pkill -f "gnoland start" 2>/dev/null || true

    echo -e "${GREEN}Clearing old database...${NC}"
    rm -rf "$GNOLAND_HOME/db" "$GNOLAND_HOME/wal"

    echo -e "${GREEN}Downloading and decompressing Gno.land snapshot...${NC}"
    mkdir -p "$GNOLAND_HOME"
    curl -o - -fL "$UTSA_SNAPSHOT_URL" | lz4 -c -d - | tar -x -C "$GNOLAND_HOME/"

    echo -e "${GREEN}Restarting Gnoland service...${NC}"
    sudo systemctl restart "$GNOLAND_SERVICE_NAME"

    echo -e "${GREEN}Snapshot setup completed successfully.${NC}"
    echo -e "${YELLOW}Showing live logs. Press Ctrl+C to stop following logs.${NC}"
    sudo journalctl -u "$GNOLAND_SERVICE_NAME" -f -o cat
}

show_menu
read -r -p "Enter your choice: " provider_choice

case "$provider_choice" in
    1) apply_utsa_snapshot ;;
    2) echo -e "${GREEN}Exiting.${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid choice. Exiting.${NC}"; exit 1 ;;
esac
