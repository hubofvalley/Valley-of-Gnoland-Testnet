#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
ORANGE='\033[38;5;214m'
RESET='\033[0m'

source "$HOME/.bash_profile" 2>/dev/null

if [ -z "${GNO_SOURCE_DIR:-}" ] || [ "$GNO_SOURCE_DIR" = "$HOME/gno-src-test13" ]; then
    GNO_SOURCE_DIR="$HOME/gno"
fi
if [ -z "${GNOLAND_HOME:-}" ] || [ "$GNOLAND_HOME" = "$HOME/.gnoland" ] || [ "$GNOLAND_HOME" = "$HOME/gnoland-data" ]; then
    GNOLAND_HOME="$GNO_SOURCE_DIR/gnoland-data"
fi
GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$GNO_SOURCE_DIR/genesis.json}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
if [ "$GNOROOT" = "$HOME/gno-src-test13" ]; then
    GNOROOT="$GNO_SOURCE_DIR"
fi
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
export GNOROOT
export PATH="$HOME/go/bin:$PATH"
GNOLAND_CHAIN_ID=${GNOLAND_CHAIN_ID:-test-13}
GNOLAND_PUBLIC_REMOTE=${GNOLAND_PUBLIC_REMOTE:-https://rpc.test13.testnets.gno.land}
GNOLAND_REMOTE=${GNOLAND_REMOTE:-http://127.0.0.1:26657}
GNO_RELEASE_TAG="chain/test13"
GNO_RELEASE_COMMIT="75c4bdf0598e7d7732c7f5d6fdd7ea4a03a3bd28"
SENTRY_PEERS="g142k7zc2qym3c0u6jmkf6rv26llgr2f4nakmlmt@sentry-1.test13.testnets.gno.land:26656,g1lxkf9gn7kddrr26c640ww5wg3ezsm22we8cjpc@sentry-2.test13.testnets.gno.land:26656"
GV_VALIDATOR_PROFILE_URL="https://test13.testnets.gno.land/r/gnops/valopers:g19sqhfxveuzdmf244xsslmwd638l9mjcdq76hym"
GV_GNOLAND_RPC_URL="https://lightnode-rpc-gnoland.grandvalleys.com"
GV_GNOLAND_PEER_ENDPOINT="peer-gnoland.grandvalleys.com:18656"
GV_GNOLAND_PEER_ID="g1c2s40hsjtgv25nnrtgjfqa9cn4v5z9l7pgyceh"
GV_GNOLAND_PEER="${GV_GNOLAND_PEER_ID}@${GV_GNOLAND_PEER_ENDPOINT}"

if [ -z "${GNOLAND_SERVICE_NAME:-}" ]; then
    echo -e "${YELLOW}Service name configuration not found.${RESET}"
    read -r -p "Enter Service Name (default 'gnoland'): " INPUT_SVC
    GNOLAND_SERVICE_NAME=${INPUT_SVC:-gnoland}
    echo "export GNOLAND_SERVICE_NAME=\"$GNOLAND_SERVICE_NAME\"" >> "$HOME/.bash_profile"
    export GNOLAND_SERVICE_NAME
fi

LOGO="
 __      __     _ _
 \ \    / /    | | |
  \ \  / /__ _ | | |  ___  _   _
   \ \/ // _\` || | | / _ \| | | |
    \  /| (_| || | ||  __/| |_| |
     \/  \__,_||_|_| \___| \__, |
                             __/ |
                            |___/
          ___   __
         / _ \ / _|
        | (_) | |_
         \___/|_|
   _____             _                 _
  / ____|           | |               | |
 | |  __ _ __   ___ | | __ _ _ __   __| |
 | | |_ | '_ \ / _ \| |/ _\` | '_ \ / _\` |
 | |__| | | | | (_) | | (_| | | | | (_| |
  \_____|_| |_|\___/|_|\__,_|_| |_|\__,_|
"

INTRO="
Valley of Gnoland by ${ORANGE}Grand Valley${RESET}

${GREEN}Gno.land Test13 Node System Requirements${RESET}
${YELLOW}| Category  | Requirements |
| --------- | ------------ |
| CPU       | 4+ vCPU      |
| RAM       | 8+ GB        |
| Storage   | 200+ GB SSD  |
| Bandwidth | 100+ MBit/s  |${RESET}

- service file name: ${CYAN}${GNOLAND_SERVICE_NAME}.service${RESET}
- current network: ${CYAN}Gno.land Test13${RESET}
- current chain ID: ${CYAN}test-13${RESET}
- native denom: ${CYAN}ugnot${RESET}
- binaries: ${CYAN}$HOME/go/bin/gnoland, $HOME/go/bin/gnokey${RESET}
- node directory: ${CYAN}${GNOLAND_HOME}${RESET}
- genesis file: ${CYAN}${GNOLAND_GENESIS}${RESET}
- GNOROOT: ${CYAN}${GNOROOT}${RESET}
"

PRIVACY_SAFETY_STATEMENT="
${YELLOW}Privacy and Safety Statement${RESET}

${GREEN}No User Data Stored Externally${RESET}
- This script does not store any user data externally. All operations are performed locally on your machine.

${GREEN}Candidate-only Validator Gate${RESET}
- Test13 registration creates a validator candidate profile only.
- GovDAO approval is required before a candidate joins the active validator set.

${GREEN}Security Best Practices${RESET}
- Always verify the script and official upstream links before running.
- Keep operator mnemonics and node secrets offline.
- Use burner/testnet-only keys.

${GREEN}Disclaimer${RESET}
- Use this script at your own risk.
"

ENDPOINTS="${GREEN}
Gno.land useful links:${RESET}
- Official Docs: ${BLUE}https://docs.gno.land/${RESET}
- Networks: ${BLUE}https://docs.gno.land/resources/gnoland-networks/${RESET}
- GitHub: ${BLUE}https://github.com/gnolang/gno${RESET}
- Test13 Release: ${BLUE}https://github.com/gnolang/gno/releases/tag/chain/test13${RESET}
- Test13 Validator Docs: ${BLUE}https://raw.githubusercontent.com/gnolang/gno/chain/test13/misc/deployments/test13.gno.land/VALIDATOR.md${RESET}
- Faucet: ${BLUE}https://test13.testnets.gno.land/faucet${RESET}
- Status: ${BLUE}https://status.test13.testnets.gno.land${RESET}
- Valoper Candidates: ${BLUE}https://test13.testnets.gno.land/r/gnops/valopers${RESET}
- Active Validators Realm: ${BLUE}https://test13.testnets.gno.land/r/sys/validators/v3${RESET}

${GREEN}Network facts:${RESET}
- Chain ID: ${CYAN}test-13${RESET}
- RPC: ${CYAN}https://rpc.test13.testnets.gno.land${RESET}
- Official sentry peers: ${CYAN}${SENTRY_PEERS}${RESET}
- Genesis SHA256: ${CYAN}56f56e135174feff9f93283d5ec7e4ec955cd5155108aff5009d4fd51c5adaf2${RESET}

${GREEN}Grand Valley public endpoints:${RESET}
- RPC Node: ${BLUE}${GV_GNOLAND_RPC_URL}${RESET}
- Public Peer Endpoint: ${CYAN}${GV_GNOLAND_PEER_ENDPOINT}${RESET}
- Persistent Peer: ${CYAN}${GV_GNOLAND_PEER}${RESET}

${GREEN}Connect with Grand Valley:${RESET}
- X: ${BLUE}https://x.com/bacvalley${RESET}
- GitHub: ${BLUE}https://github.com/hubofvalley${RESET}
- Email: ${BLUE}letsbuidltogether@grandvalleys.com${RESET}
"

echo -e "$LOGO"
echo -e "$PRIVACY_SAFETY_STATEMENT"
echo -e "\n${YELLOW}Press Enter to continue...${RESET}"
read -r

echo -e "$INTRO"
echo -e "$ENDPOINTS"
echo -e "\n${YELLOW}Press Enter to continue${RESET}"
read -r

sed -i '/^export GNOLAND_CHAIN_ID=/d;/^export GNOLAND_HOME=/d;/^export GNOLAND_GENESIS=/d;/^export GNOKEY_HOME=/d;/^export GNO_SOURCE_DIR=/d;/^export GNOROOT=/d;/^export GNOLAND_PUBLIC_REMOTE=/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true
{
    echo "export GNOLAND_CHAIN_ID=\"test-13\""
    echo "export GNOLAND_HOME=\"$GNOLAND_HOME\""
    echo "export GNOLAND_GENESIS=\"$GNOLAND_GENESIS\""
    echo "export GNOKEY_HOME=\"$GNOKEY_HOME\""
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    echo "export GNOLAND_PUBLIC_REMOTE=\"https://rpc.test13.testnets.gno.land\""
    echo 'export PATH="$HOME/go/bin:$PATH"'
} >> "$HOME/.bash_profile"
source "$HOME/.bash_profile" 2>/dev/null

function gnokey_cmd() {
    gnokey -home "$GNOKEY_HOME" -remote "$GNOLAND_PUBLIC_REMOTE" "$@"
}

function get_local_rpc_port() {
    local cfg="$GNOLAND_HOME/config/config.toml"
    if [ ! -f "$cfg" ]; then
        return
    fi
    awk -F: '/laddr = "tcp:\/\/127\.0\.0\.1:/ {gsub(/".*/, "", $3); print $3; exit}' "$cfg"
}

function get_local_status_json() {
    local port
    port=$(get_local_rpc_port)
    if [ -z "$port" ]; then
        port=26657
    fi
    curl -m 5 -s "http://127.0.0.1:${port}/status"
}

function get_network_height() {
    curl -m 5 -s "$GNOLAND_PUBLIC_REMOTE/status" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null
}

function prompt_back_or_continue() {
    read -r -p "Press Enter to continue or type 'back' to go back to the menu: " user_choice
    if [[ ${user_choice,,} == "back" ]]; then
        menu
        return 1
    fi
    return 0
}

function deploy_gnoland_node() {
    clear
    echo -e "${RED}IMPORTANT DISCLAIMER AND TERMS${RESET}"
    echo -e "${YELLOW}New service:${RESET} ${CYAN}${GNOLAND_SERVICE_NAME}.service${RESET}"
    echo -e "${YELLOW}Directory:${RESET} ${CYAN}$GNOLAND_HOME${RESET}"
    echo -e "${YELLOW}Default ports:${RESET} RPC ${CYAN}26657${RESET}, P2P ${CYAN}26656${RESET}; installer can remap with a two-digit prefix."
    echo -e "${RED}Re-deploy deletes existing node data. Backup secrets first.${RESET}"
    echo
    echo "This installs a Test13 full node and does not guarantee active validator status."
    echo "GovDAO proposal approval is required after candidate registration."
    read -r -p $'\n\e[33mDo you want to proceed with installation? (yes/no): \e[0m' confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo -e "${RED}Installation cancelled.${RESET}"
        menu
        return
    fi
    bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/gnoland_node_install_testnet.sh)
    menu
}

function update_gnoland_binary() {
    echo -e "${YELLOW}Update gnoland and gnokey to the pinned Test13 release binaries.${RESET}"
    if ! prompt_back_or_continue; then
        return
    fi
    bash <(curl -s https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/resources/gnoland_update.sh)
    menu
}

function add_peers() {
    echo "Select an option:"
    echo "1. Add peers manually"
    echo "2. Reset to official Test13 sentry peers"
    echo "3. Use Grand Valley's peer node"
    echo "4. Back"
    read -r -p "Enter your choice (1, 2, 3, or 4): " choice

    if [ "$choice" = "4" ]; then
        menu
        return
    fi

    CFG="$GNOLAND_HOME/config/config.toml"
    if [ ! -f "$CFG" ]; then
        echo -e "${RED}config.toml not found at $CFG. Deploy the node first.${RESET}"
        menu
        return
    fi

    case $choice in
        1)
            read -r -p "Enter peers (comma-separated id@host:port): " peers
            echo "You entered: $peers"
            read -r -p "Proceed? (yes/no): " confirm
            if [[ "${confirm,,}" == "yes" ]]; then
                gnoland config set -config-path "$CFG" p2p.persistent_peers "$peers"
                echo "Peers updated."
            fi
            ;;
        2)
            gnoland config set -config-path "$CFG" p2p.persistent_peers "$SENTRY_PEERS"
            echo "Official sentry peers restored."
            ;;
        3)
            echo "Grand Valley's peer node:"
            echo "$GV_GNOLAND_PEER"
            read -r -p "Use Grand Valley's peer node? (yes/no): " confirm
            if [[ "${confirm,,}" == "yes" ]]; then
                gnoland config set -config-path "$CFG" p2p.persistent_peers "$GV_GNOLAND_PEER"
                echo "Grand Valley's peer node added."
            fi
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "\n${YELLOW}Restart node to apply changes.${RESET}"
    menu
}

function show_node_status() {
    local port status_json node_height catching_up network_height
    port=$(get_local_rpc_port)
    [ -z "$port" ] && port=26657
    status_json=$(get_local_status_json)
    node_height=$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)
    if [ -z "$node_height" ]; then
        echo -e "${RED}Cannot reach local RPC at http://127.0.0.1:${port}/status. Is ${GNOLAND_SERVICE_NAME}.service running?${RESET}"
    else
        echo -e "${CYAN}Local RPC status: curl http://127.0.0.1:${port}/status | jq${RESET}"
        echo "$status_json" | jq .
        echo
        catching_up=$(echo "$status_json" | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null)
        [ -z "$catching_up" ] && catching_up="unknown"
        echo "Local Gnoland node block height: $node_height"
        network_height=$(get_network_height)
        if [ -n "$network_height" ]; then
            echo "Network latest block height: $network_height"
            echo "Block Difference: $((network_height - node_height))"
        else
            echo -e "${YELLOW}Network latest block height unavailable from $GNOLAND_PUBLIC_REMOTE${RESET}"
        fi
        echo -e "Catching up: ${YELLOW}$catching_up${RESET}"
    fi
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function show_logs() {
    trap 'echo -e "\nStopping logs and returning to main menu...";' INT
    sudo journalctl -u "$GNOLAND_SERVICE_NAME" -fn 100 -o cat || true
    trap - INT
    menu
}

function create_operator_key() {
    echo "Choose an option:"
    echo "1. Create a new operator key"
    echo "2. Recover an existing key from mnemonic"
    echo "3. List local keys"
    echo "4. Back"
    read -r -p "Enter your choice: " choice

    case $choice in
        1)
            read -r -p "Enter key name (default 'operator'): " keyname
            keyname=${keyname:-operator}
            gnokey -home "$GNOKEY_HOME" add "$keyname"
            echo -e "\n${RED}WRITE DOWN THE MNEMONIC ABOVE AND STORE IT OFFLINE. It will not be shown again.${RESET}"
            ;;
        2)
            read -r -p "Enter key name (default 'operator'): " keyname
            keyname=${keyname:-operator}
            gnokey -home "$GNOKEY_HOME" add -recover "$keyname"
            ;;
        3)
            gnokey -home "$GNOKEY_HOME" list
            ;;
        4)
            menu
            return
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "\n${YELLOW}Fund the operator g1 address via: ${BLUE}https://test13.testnets.gno.land/faucet${RESET}"
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function show_validator_pubkey() {
    echo -e "${CYAN}Your validator consensus public key:${RESET}"
    (cd "$GNO_SOURCE_DIR" && gnoland secrets get validator_key)
    echo -e "\n${YELLOW}Use the gpub1... value for valoper registration. Press Enter to go back.${RESET}"
    read -r
    menu
}

function register_valoper_candidate() {
    echo -e "${CYAN}Register Gno.land Test13 Valoper Candidate${RESET}"
    echo -e "${YELLOW}This broadcasts a transaction. It creates a candidate profile only, not active validator status.${RESET}"
    echo -e "${YELLOW}Requirements: synced node, funded operator key, and consensus gpub1... from option 2b.${RESET}"
    if ! prompt_back_or_continue; then
        return
    fi

    read -r -p "Enter operator key name (default 'operator'): " KEY_NAME
    KEY_NAME=${KEY_NAME:-operator}
    read -r -p "Enter validator moniker: " MONIKER
    read -r -p "Enter short validator description: " DESCRIPTION
    read -r -p "Enter infrastructure type (cloud/on-prem/data-center): " INFRA_TYPE
    read -r -p "Enter operator g1... address: " OPERATOR_ADDR
    read -r -p "Enter consensus gpub1... public key: " CONSENSUS_PUBKEY

    echo -e "\n${YELLOW}Transaction preview:${RESET}"
    cat <<EOF
gnokey maketx call \\
  --pkgpath gno.land/r/gnops/valopers \\
  --func Register \\
  --args "$MONIKER" \\
  --args "$DESCRIPTION" \\
  --args "$INFRA_TYPE" \\
  --args "$OPERATOR_ADDR" \\
  --args "$CONSENSUS_PUBKEY" \\
  --gas-fee 1000000ugnot --gas-wanted 80000000 \\
  --chainid test-13 \\
  --remote $GNOLAND_PUBLIC_REMOTE \\
  --broadcast \\
  $KEY_NAME
EOF
    read -r -p $'\n\e[33mBroadcast registration transaction? (yes/no): \e[0m' confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo "Cancelled."
        menu
        return
    fi

    gnokey_cmd maketx call \
        -pkgpath gno.land/r/gnops/valopers \
        -func Register \
        -args "$MONIKER" \
        -args "$DESCRIPTION" \
        -args "$INFRA_TYPE" \
        -args "$OPERATOR_ADDR" \
        -args "$CONSENSUS_PUBKEY" \
        -gas-fee 1000000ugnot \
        -gas-wanted 80000000 \
        -chainid "$GNOLAND_CHAIN_ID" \
        -broadcast \
        "$KEY_NAME"

    echo -e "\n${GREEN}Candidate registration submitted if broadcast succeeded.${RESET}"
    echo -e "${YELLOW}Next gate: GovDAO proposal approval via r/sys/validators/v3.${RESET}"
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function query_balance_or_realm() {
    echo "Choose an option:"
    echo "1. Query account path manually"
    echo "2. Open valoper candidate page"
    echo "3. Back"
    read -r -p "Enter your choice: " choice
    case $choice in
        1)
            read -r -p "Enter ABCI query path: " path
            gnokey_cmd query "$path"
            ;;
        2)
            echo "Valoper candidates: https://test13.testnets.gno.land/r/gnops/valopers"
            echo "Active validators: https://test13.testnets.gno.land/r/sys/validators/v3"
            ;;
        3)
            menu
            return
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function backup_node_secrets() {
    if [ -d "$GNOLAND_HOME/secrets" ]; then
        backup="$HOME/gnoland-secrets-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$backup" -C "$GNOLAND_HOME" secrets
        chmod 600 "$backup"
        echo -e "${YELLOW}Node secrets copied to $backup${RESET}"
        echo -e "${RED}Move it somewhere safe and offline.${RESET}"
    else
        echo -e "${RED}No secrets directory found at $GNOLAND_HOME/secrets. Deploy node first.${RESET}"
    fi
    menu
}

function restart_gnoland() {
    sudo systemctl daemon-reload
    sudo systemctl restart "$GNOLAND_SERVICE_NAME"
    echo -e "${GREEN}${GNOLAND_SERVICE_NAME}.service restarted.${RESET}"
    menu
}

function stop_gnoland() {
    sudo systemctl stop "$GNOLAND_SERVICE_NAME"
    echo -e "${YELLOW}${GNOLAND_SERVICE_NAME}.service stopped.${RESET}"
    menu
}

function delete_gnoland_node() {
    echo -e "${YELLOW}You are about to delete the Gnoland node.${RESET}"
    echo -e "${RED}BACKUP OPERATOR MNEMONIC AND NODE SECRETS BEFORE YOU DO THIS.${RESET}"
    if ! prompt_back_or_continue; then
        return
    fi
    sudo systemctl stop "$GNOLAND_SERVICE_NAME" || true
    sudo systemctl disable "$GNOLAND_SERVICE_NAME" || true
    sudo rm -f "/etc/systemd/system/${GNOLAND_SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    rm -rf "$GNOLAND_HOME"
    rm -f "$GNOLAND_GENESIS"
    rm -f "$GNOLAND_BIN" "$GNOKEY_BIN"
    sudo rm -f /usr/local/bin/gnoland /usr/local/bin/gnokey
    sed -i '/GNOLAND_/d;/GNOKEY_/d;/GNO_SOURCE_DIR/d;/GNOROOT/d;/go\/bin/d' "$HOME/.bash_profile"
    echo -e "${RED}Gnoland node deleted. Local gnokey home was not deleted: $GNOKEY_HOME${RESET}"
    menu
}

function show_endpoints() {
    echo -e "$ENDPOINTS"
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function show_guidelines() {
    echo -e "${CYAN}Guidelines on How to Use the Valley of Gnoland${RESET}"
    echo -e "${GREEN}Recommended flow:${RESET}"
    echo " - 1a Deploy node -> wait until 1d shows synced"
    echo " - 2a Create/recover operator key -> fund via faucet"
    echo " - 2b Show consensus pubkey"
    echo " - 2c Register valoper candidate"
    echo " - 3d Backup node secrets"
    echo -e "${YELLOW}Candidate registration is not active validator admission. GovDAO approval is required.${RESET}"
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function menu() {
    clear
    echo -e "$LOGO"
    local node_height network_height catching_up diff
    node_height=$(get_local_status_json | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)
    catching_up=$(get_local_status_json | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null)
    network_height=$(get_network_height)
    [ -z "$node_height" ] && node_height="N/A"
    [ -z "$network_height" ] && network_height="N/A"
    [ -z "$catching_up" ] && catching_up="N/A"
    if [[ "$node_height" =~ ^[0-9]+$ ]] && [[ "$network_height" =~ ^[0-9]+$ ]]; then
        diff=$((network_height - node_height))
    else
        diff="N/A"
    fi

    echo -e "${GREEN}Valley of Gnoland by Grand Valley${RESET}"
    echo -e "Network Height: ${CYAN}${network_height}${RESET} | Local Height: ${CYAN}${node_height}${RESET} | Block Difference: ${YELLOW}${diff}${RESET} | Catching up: ${YELLOW}${catching_up}${RESET}"
    echo
    echo "1. Node Interactions"
    echo "   1a. Deploy/Re-deploy Gnoland Node"
    echo "   1b. Update Gnoland/Gnokey Binaries"
    echo "   1c. Add/Reset Peers"
    echo "   1d. Show Node Status"
    echo "   1e. Show Node Logs"
    echo
    echo "2. Validator/Key Interactions"
    echo "   2a. Create/Recover/List Operator Key"
    echo "   2b. Show Validator Consensus Pubkey"
    echo "   2c. Register Valoper Candidate"
    echo "   2d. Query / Show Valoper Pages"
    echo
    echo "3. Node Management"
    echo "   3a. Restart Gnoland Node"
    echo "   3b. Stop Gnoland Node"
    echo "   3c. Delete Gnoland Node"
    echo "   3d. Backup Node Secrets"
    echo
    echo "4. Show Endpoints & Useful Links"
    echo "5. Show Guidelines"
    echo "6. Exit"
    echo
    echo -e "Grand Valley's Validator Profile: ${BLUE}${GV_VALIDATOR_PROFILE_URL}${RESET}"
    echo -e "${GREEN}Let's Buidl Gnoland Together - Grand Valley${RESET}"
    if ! read -r -p "Choose an option: " choice; then
        echo
        echo "Let's Buidl Gnoland Together - Grand Valley"
        exit 0
    fi
    case "${choice,,}" in
        1a|1-a) deploy_gnoland_node ;;
        1b|1-b) update_gnoland_binary ;;
        1c|1-c) add_peers ;;
        1d|1-d) show_node_status ;;
        1e|1-e) show_logs ;;
        2a|2-a) create_operator_key ;;
        2b|2-b) show_validator_pubkey ;;
        2c|2-c) register_valoper_candidate ;;
        2d|2-d) query_balance_or_realm ;;
        3a|3-a) restart_gnoland ;;
        3b|3-b) stop_gnoland ;;
        3c|3-c) delete_gnoland_node ;;
        3d|3-d) backup_node_secrets ;;
        4) show_endpoints ;;
        5) show_guidelines ;;
        6) echo "Let's Buidl Gnoland Together - Grand Valley"; exit 0 ;;
        *)
            echo "Invalid choice."
            sleep 1
            menu
            ;;
    esac
}

menu
