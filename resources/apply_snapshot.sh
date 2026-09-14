#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Snapshot support stays visible in the menu for UX continuity, but the Pearl
# path is deliberately fail-closed until a provider and verification contract
# are independently reviewed.
# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_TESTNET_HOME=${GNOLAND_TESTNET_HOME:-$GNO_SOURCE_DIR/gnoland-data}
GNOLAND_TESTNET_SERVICE_NAME=${GNOLAND_TESTNET_SERVICE_NAME:-gnoland-testnet}

show_menu() {
    echo -e "${GREEN}Pearl snapshot support is disabled.${RESET}"
    echo "1. Disabled"
    echo "2. Exit"
}

apply_snapshot() {
    echo -e "${YELLOW}Snapshot application is disabled for Pearl.${RESET}"
    echo "No provider was executed, no service was stopped, and no node data was changed."
    echo "Verified runtime targets: service=${GNOLAND_TESTNET_SERVICE_NAME}.service home=${GNOLAND_TESTNET_HOME}"
    return 1
}

main() {
    show_menu
    read -r -p "Enter your choice: " provider_choice
    case "$provider_choice" in
        1)
            apply_snapshot
            ;;
        2)
            echo -e "${GREEN}Exiting.${RESET}"
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${RESET}" >&2
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
