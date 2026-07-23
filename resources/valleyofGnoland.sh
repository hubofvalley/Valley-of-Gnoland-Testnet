#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
ORANGE='\033[38;5;214m'
RESET='\033[0m'

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null

OS_USER=$(id -un)

if [ -n "${SUDO_USER:-}" ]; then
    echo -e "${RED}Run Valley of Gnoland as the node OS user, not with sudo.${RESET}" >&2
    echo "The tool requests sudo only when system access is required." >&2
    exit 1
fi

if [ -z "${GNO_SOURCE_DIR:-}" ]; then
    GNO_SOURCE_DIR="$HOME/gno"
fi
if [ -z "${GNOLAND_HOME:-}" ] || [ "$GNOLAND_HOME" = "$HOME/.gnoland" ] || [ "$GNOLAND_HOME" = "$HOME/gnoland-data" ]; then
    GNOLAND_HOME="$GNO_SOURCE_DIR/gnoland-data"
fi
GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$GNO_SOURCE_DIR/genesis.json}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
export GNOROOT
export PATH="$HOME/go/bin:$PATH"
GNOLAND_CHAIN_ID=${GNOLAND_CHAIN_ID:-topaz-1}
GNOLAND_PUBLIC_REMOTE=${GNOLAND_PUBLIC_REMOTE:-https://rpc.topaz.testnets.gno.land}
GNOLAND_REMOTE=${GNOLAND_REMOTE:-}
TOPAZ_SEEDS="g19q07ssuafhmg6r7ys7wp7rpc4jxc85cpvdy426@seed-1.topaz.testnets.gno.land:26656,g15k98e65gm8h7fdr3yr4tqn82lvch4a97a3sg3j@seed-2.topaz.testnets.gno.land:26656"

while :; do
    if [ -z "${GNOLAND_SERVICE_NAME:-}" ]; then
        echo -e "${YELLOW}Service name configuration not found.${RESET}"
        read -r -p "Enter Service Name (default 'gnoland'): " INPUT_SVC
        GNOLAND_SERVICE_NAME=${INPUT_SVC:-gnoland}
    fi
    GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
    if [[ "$GNOLAND_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
        break
    fi
    echo -e "${RED}Service name must start with a letter or number and may contain _, ., @, and -.${RESET}"
    GNOLAND_SERVICE_NAME=""
done

sed -i '/^export GNOLAND_SERVICE_NAME=/d' "$HOME/.bash_profile" 2>/dev/null || true
echo "export GNOLAND_SERVICE_NAME=\"$GNOLAND_SERVICE_NAME\"" >> "$HOME/.bash_profile"
export GNOLAND_SERVICE_NAME

service_belongs_to_current_instance() {
    local service_file unit_user unit_workdir
    service_file=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
    [ -n "$service_file" ] || return 0
    if [ ! -f "$service_file" ]; then
        echo -e "${RED}Cannot inspect existing service: $service_file${RESET}" >&2
        return 1
    fi
    unit_user=$(sed -n 's/^User=//p' "$service_file" | tail -n 1)
    unit_workdir=$(sed -n 's/^WorkingDirectory=//p' "$service_file" | tail -n 1)
    if [ "$unit_user" != "$OS_USER" ] || [ "$unit_workdir" != "$GNO_SOURCE_DIR" ]; then
        echo -e "${RED}${GNOLAND_SERVICE_NAME}.service belongs to another instance.${RESET}" >&2
        echo "Existing User=${unit_user:-unknown}, WorkingDirectory=${unit_workdir:-unknown}" >&2
        echo "Current User=$OS_USER, WorkingDirectory=$GNO_SOURCE_DIR" >&2
        return 1
    fi
}

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

${GREEN}Gno.land Topaz Node System Requirements${RESET}
${YELLOW}| Category  | Requirements |
| --------- | ------------ |
| CPU       | 4+ vCPU      |
| RAM       | 8+ GB        |
| Storage   | 200+ GB SSD  |
| Bandwidth | 100+ MBit/s  |${RESET}

- service file name: ${CYAN}${GNOLAND_SERVICE_NAME}.service${RESET}
- current network: ${CYAN}Gno.land Topaz${RESET}
- current chain ID: ${CYAN}topaz-1${RESET}
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
- Topaz registration creates a validator candidate profile only.
- Existing Test13 validators must reuse the same operator g1 address.
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
- Topaz Release: ${BLUE}https://github.com/gnolang/gno/releases/tag/chain/topaz${RESET}
- Topaz Validator Docs: ${BLUE}https://github.com/gnolang/gno/blob/chain/topaz/misc/deployments/topaz.gno.land/VALIDATOR.md${RESET}
- Faucet: ${BLUE}https://topaz.testnets.gno.land/faucet${RESET}
- Valoper Candidates: ${BLUE}https://topaz.testnets.gno.land/r/gnops/valopers${RESET}
- Active Validators Realm: ${BLUE}https://topaz.testnets.gno.land/r/sys/validators/v3${RESET}

${GREEN}Network facts:${RESET}
- Chain ID: ${CYAN}topaz-1${RESET}
- RPC: ${CYAN}https://rpc.topaz.testnets.gno.land${RESET}
- Official seeds: ${CYAN}${TOPAZ_SEEDS}${RESET}
- Genesis SHA256: ${CYAN}2dd049f973b82858727440df9aff5722cb0b322fd00890f40f2b0688276898ff${RESET}

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
    echo "export GNOLAND_CHAIN_ID=\"topaz-1\""
    echo "export GNOLAND_HOME=\"$GNOLAND_HOME\""
    echo "export GNOLAND_GENESIS=\"$GNOLAND_GENESIS\""
    echo "export GNOKEY_HOME=\"$GNOKEY_HOME\""
    echo "export GNO_SOURCE_DIR=\"$GNO_SOURCE_DIR\""
    echo "export GNOROOT=\"$GNOROOT\""
    echo "export GNOLAND_PUBLIC_REMOTE=\"https://rpc.topaz.testnets.gno.land\""
    # shellcheck disable=SC2016
    echo 'export PATH="$HOME/go/bin:$PATH"'
} >> "$HOME/.bash_profile"
# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null

function gnokey_cmd() {
    gnokey -home "$GNOKEY_HOME" -remote "$GNOLAND_PUBLIC_REMOTE" "$@"
}

function operator_key_exists() {
    gnokey -home "$GNOKEY_HOME" list 2>/dev/null |
        awk -v key="$1" '$2 == key { found=1 } END { exit !found }'
}

function get_rpc_port_from_remote() {
    local remote="${GNOLAND_REMOTE:-}"
    if [[ "$remote" =~ :([0-9]+)/?$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

function get_local_rpc_port() {
    local cfg="$GNOLAND_HOME/config/config.toml" port
    if [ -f "$cfg" ]; then
        port=$(awk -F: '
            /^[[:space:]]*\[rpc\][[:space:]]*$/ {in_rpc=1; next}
            /^[[:space:]]*\[/ {in_rpc=0}
            in_rpc && /^[[:space:]]*laddr = "tcp:\/\// {
                gsub(/".*/, "", $NF)
                print $NF
                exit
            }
        ' "$cfg")
        if [ -z "$port" ]; then
            port=$(awk -F: '/laddr = "tcp:\/\/127\.0\.0\.1:/ {gsub(/".*/, "", $3); print $3; exit}' "$cfg")
        fi
        if [ -n "$port" ]; then
            echo "$port"
            return
        fi
    fi
    get_rpc_port_from_remote
}

function get_local_rpc_url() {
    local port
    port=$(get_local_rpc_port)
    if [ -n "$port" ]; then
        echo "http://127.0.0.1:${port}"
    else
        echo "${GNOLAND_REMOTE:-http://127.0.0.1:${GNOLAND_PORT:-26}657}"
    fi
}

function get_local_status_json() {
    local rpc_url
    rpc_url=$(get_local_rpc_url)
    curl -m 5 -s "${rpc_url%/}/status"
}

function get_network_height() {
    curl -m 5 -s "$GNOLAND_PUBLIC_REMOTE/status" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null
}

function get_local_net_info_json() {
    local rpc_url
    rpc_url=$(get_local_rpc_url)
    curl -m 5 -s "${rpc_url%/}/net_info"
}

function prompt_back_or_continue() {
    read -r -p "Press Enter to continue or type 'back' to go back to the menu: " user_choice
    if [[ ${user_choice,,} == "back" ]]; then
        menu
        return 1
    fi
    return 0
}

function run_repository_script() {
    local relative_path=$1
    local script_file exit_code
    script_file=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/main/${relative_path}" -o "$script_file"; then
        rm -f "$script_file"
        echo -e "${RED}Failed to download ${relative_path} from main. Nothing was executed.${RESET}"
        return 1
    fi
    chmod +x "$script_file"
    bash "$script_file"
    exit_code=$?
    rm -f "$script_file"
    if [ "$exit_code" -ne 0 ]; then
        echo -e "${RED}${relative_path} stopped with exit code ${exit_code}.${RESET}"
        echo -e "${YELLOW}Read the Stage, Line, and Command shown above. Returning to the menu.${RESET}"
        return "$exit_code"
    fi
    return 0
}

function deploy_gnoland_node() {
    clear
    echo -e "${RED}IMPORTANT DISCLAIMER AND TERMS${RESET}"
    echo -e "${YELLOW}New service:${RESET} ${CYAN}${GNOLAND_SERVICE_NAME}.service${RESET}"
    echo -e "${YELLOW}Directory:${RESET} ${CYAN}$GNOLAND_HOME${RESET}"
    echo -e "${YELLOW}Default ports:${RESET} ABCI ${CYAN}26658${RESET}, P2P ${CYAN}26656${RESET}, RPC ${CYAN}26657${RESET}; installer remaps all three local listeners with the chosen two-digit prefix."
    echo -e "${RED}Migration replaces chain data only inside the current OS user's node directory.${RESET}"
    echo -e "${YELLOW}The installer backs up node secrets and the operator keyring before cleanup.${RESET}"
    echo
    echo "This installs a Topaz full node and does not guarantee active validator status."
    echo "GovDAO proposal approval is required after candidate registration."
    read -r -p $'\n\e[33mDo you want to proceed with installation? (yes/no): \e[0m' confirm
    if [[ "${confirm,,}" != "yes" ]]; then
        echo -e "${RED}Installation cancelled.${RESET}"
        menu
        return
    fi
    run_repository_script "resources/gnoland_node_install_testnet.sh" || true
    menu
}

function update_gnoland_binary() {
    echo -e "${YELLOW}Update gnoland and gnokey to the pinned Topaz release binaries.${RESET}"
    if ! prompt_back_or_continue; then
        return
    fi
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Update blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    run_repository_script "resources/gnoland_update.sh" || true
    menu
}

function apply_snapshot() {
    echo -e "${RED}Topaz snapshot unavailable. The old Test13 snapshot is blocked for safety.${RESET}"
    read -r -p "Press Enter to return to the menu."
    menu
}

function add_peers() {
    echo "Select an option:"
    echo "1. Add peers manually"
    echo "2. Reset to official Topaz seeds"
    echo "3. Back"
    read -r -p "Enter your choice (1, 2, or 3): " choice

    if [ "$choice" = "3" ]; then
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
            gnoland config set -config-path "$CFG" p2p.seeds "$TOPAZ_SEEDS"
            gnoland config set -config-path "$CFG" p2p.persistent_peers "$TOPAZ_SEEDS"
            echo "Official Topaz seeds and persistent peers restored."
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "\n${YELLOW}Restart node to apply changes.${RESET}"
    menu
}

function show_node_status() {
    local rpc_url status_json net_info_json node_height catching_up network_height latest_block_time validator_address peer_count service_state disk_line block_diff sync_status
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Status blocked: selected service belongs to another instance.${RESET}"
        menu
        return
    fi
    rpc_url=$(get_local_rpc_url)
    status_json=$(get_local_status_json)
    net_info_json=$(get_local_net_info_json)
    service_state=$(systemctl is-active "$GNOLAND_SERVICE_NAME" 2>/dev/null || true)
    [ -z "$service_state" ] && service_state="unknown"
    disk_line=$(df -h "$GNOLAND_HOME" 2>/dev/null | awk 'NR==2 {print $4 " free of " $2 " (" $5 " used)"}')
    [ -z "$disk_line" ] && disk_line="unavailable for $GNOLAND_HOME"

    echo -e "${CYAN}Operational health summary${RESET}"
    echo "Service: ${GNOLAND_SERVICE_NAME}.service ($service_state)"
    echo "Local RPC: $rpc_url"
    echo "Node directory: $GNOLAND_HOME"
    echo "Disk: $disk_line"
    echo

    node_height=$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)
    if [ -z "$node_height" ]; then
        echo -e "${RED}Cannot reach local RPC at ${rpc_url%/}/status. Is ${GNOLAND_SERVICE_NAME}.service running?${RESET}"
    else
        catching_up=$(echo "$status_json" | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null)
        [ -z "$catching_up" ] && catching_up="unknown"
        latest_block_time=$(echo "$status_json" | jq -r '.result.sync_info.latest_block_time // empty' 2>/dev/null)
        [ -z "$latest_block_time" ] && latest_block_time="unknown"
        validator_address=$(echo "$status_json" | jq -r '.result.validator_info.address // empty' 2>/dev/null)
        [ -z "$validator_address" ] && validator_address="unknown"
        peer_count=$(echo "$net_info_json" | jq -r '.result.n_peers // empty' 2>/dev/null)
        [ -z "$peer_count" ] && peer_count="unknown"

        echo "Local height: $node_height"
        network_height=$(get_network_height)
        if [ -n "$network_height" ]; then
            echo "Network height: $network_height"
            if [[ "$network_height" =~ ^[0-9]+$ ]] && [[ "$node_height" =~ ^[0-9]+$ ]]; then
                block_diff=$((network_height - node_height))
                echo "Block difference: $block_diff"
                if [ "$block_diff" -le 0 ]; then
                    sync_status="synced"
                else
                    sync_status="behind by ${block_diff} blocks"
                    if [ "$catching_up" = "true" ]; then
                        sync_status="${sync_status} (catching up)"
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}Network latest block height unavailable from $GNOLAND_PUBLIC_REMOTE${RESET}"
        fi
        if [ -z "$sync_status" ]; then
            sync_status="catching_up=${catching_up}"
        fi
        echo "Sync status: $sync_status"
        echo "Connected peers: $peer_count"
        echo "Latest block time: $latest_block_time"
        echo "Validator address: $validator_address"
    fi
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function show_logs() {
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Logs blocked: selected service belongs to another instance.${RESET}"
        menu
        return
    fi
    trap 'echo -e "\nStopping logs and returning to main menu...";' INT
    sudo journalctl -u "$GNOLAND_SERVICE_NAME" -fn 100 -o cat || true
    trap - INT
    menu
}

function create_operator_key() {
    echo "Choose an option:"
    echo "1. Reuse/list an existing local Test13 operator key"
    echo "2. Recover the existing Test13 operator key from mnemonic"
    echo "3. Create a new operator key"
    echo "4. Back"
    read -r -p "Enter your choice: " choice

    case $choice in
        1)
            echo -e "${YELLOW}Existing Topaz validators should use the same operator g1 address used on Test13.${RESET}"
            gnokey -home "$GNOKEY_HOME" list
            ;;
        2)
            read -r -p "Enter key name (default 'operator'): " keyname
            keyname=${keyname:-operator}
            if operator_key_exists "$keyname"; then
                echo -e "${RED}Key '$keyname' already exists. Refusing to overwrite it.${RESET}"
            else
                gnokey -home "$GNOKEY_HOME" add -recover "$keyname"
            fi
            ;;
        3)
            read -r -p "Enter key name (default 'operator'): " keyname
            keyname=${keyname:-operator}
            if operator_key_exists "$keyname"; then
                echo -e "${RED}Key '$keyname' already exists. Refusing to overwrite it.${RESET}"
            else
                gnokey -home "$GNOKEY_HOME" add "$keyname"
                echo -e "\n${RED}WRITE DOWN THE MNEMONIC ABOVE AND STORE IT OFFLINE. It will not be shown again.${RESET}"
            fi
            ;;
        4)
            menu
            return
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
    echo -e "\n${YELLOW}Fund the operator g1 address via: ${BLUE}https://topaz.testnets.gno.land/faucet${RESET}"
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
    echo -e "${CYAN}Register Gno.land Topaz Valoper Candidate${RESET}"
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
  --gas-fee 1000000ugnot --gas-wanted 50000000 \\
  --chainid topaz-1 \\
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
        -gas-wanted 50000000 \
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
            echo "Valoper candidates: https://topaz.testnets.gno.land/r/gnops/valopers"
            echo "Active validators: https://topaz.testnets.gno.land/r/sys/validators/v3"
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
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Restart blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    sudo systemctl daemon-reload
    sudo systemctl restart "$GNOLAND_SERVICE_NAME"
    echo -e "${GREEN}${GNOLAND_SERVICE_NAME}.service restarted.${RESET}"
    menu
}

function stop_gnoland() {
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Stop blocked to protect the other instance.${RESET}"
        menu
        return
    fi
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
    if ! service_belongs_to_current_instance; then
        echo -e "${RED}Delete blocked to protect the other instance.${RESET}"
        menu
        return
    fi
    canonical_home=$(realpath -m "$HOME")
    canonical_node_home=$(realpath -m "$GNOLAND_HOME")
    case "$canonical_node_home" in
        "$canonical_home"/*) ;;
        *)
            echo -e "${RED}Delete blocked: node path is outside $HOME.${RESET}"
            menu
            return
            ;;
    esac
    sudo systemctl stop "$GNOLAND_SERVICE_NAME" || true
    sudo systemctl disable "$GNOLAND_SERVICE_NAME" || true
    sudo rm -f "/etc/systemd/system/${GNOLAND_SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    rm -rf "$GNOLAND_HOME"
    rm -f "$GNOLAND_GENESIS"
    rm -f "$GNOLAND_BIN" "$GNOKEY_BIN"
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
    echo " - 1a Deploy node -> wait until 1e shows synced"
    echo " - 2a Reuse/recover the Test13 operator key (or create a new key) -> fund via faucet"
    echo " - 2b Show consensus pubkey"
    echo " - 2c Register valoper candidate"
    echo " - 3d Backup node secrets"
    echo -e "${YELLOW}Candidate registration is not active validator admission. GovDAO approval is required.${RESET}"
    echo
    echo -e "${GREEN}Node Interactions:${RESET}"
    echo "   a. Deploy/Re-deploy Gnoland Node: Migrates or installs the Topaz node."
    echo "   b. Update Gnoland/Gnokey Binaries: Refreshes the pinned Topaz binaries."
    echo "   c. Apply Snapshot: Disabled until a verified Topaz snapshot exists."
    echo "   d. Add/Reset Peers: Manages persistent peers and official seeds."
    echo "   e. Show Node Status: Shows the node health summary directly."
    echo "   f. Show Node Logs: Live-tails the Gnoland service logs."
    echo -e "${YELLOW}Press Enter to go back to main menu${RESET}"
    read -r
    menu
}

function menu() {
    clear
    echo -e "$LOGO"
    local node_height network_height catching_up diff sync_status
    node_height=$(get_local_status_json | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)
    catching_up=$(get_local_status_json | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null)
    network_height=$(get_network_height)
    [ -z "$node_height" ] && node_height="N/A"
    [ -z "$network_height" ] && network_height="N/A"
    [ -z "$catching_up" ] && catching_up="N/A"
    if [[ "$node_height" =~ ^[0-9]+$ ]] && [[ "$network_height" =~ ^[0-9]+$ ]]; then
        diff=$((network_height - node_height))
        if [ "$diff" -le 0 ]; then
            sync_status="synced"
        else
            sync_status="behind by ${diff} blocks"
            if [ "$catching_up" = "true" ]; then
                sync_status="${sync_status} (catching up)"
            fi
        fi
    else
        diff="N/A"
        sync_status="catching_up=${catching_up}"
    fi

    echo -e "${GREEN}Valley of Gnoland by Grand Valley${RESET}"
    echo -e "Network Height: ${CYAN}${network_height}${RESET} | Local Height: ${CYAN}${node_height}${RESET} | Block Difference: ${YELLOW}${diff}${RESET} | Sync Status: ${YELLOW}${sync_status}${RESET}"
    echo
    echo "1. Node Interactions"
    echo "   1a. Deploy/Re-deploy Gnoland Node"
    echo "   1b. Update Gnoland/Gnokey Binaries"
    echo "   1c. Snapshot Status (currently unavailable)"
    echo "   1d. Add/Reset Peers"
    echo "   1e. Show Node Status"
    echo "   1f. Show Node Logs"
    echo
    echo "2. Validator/Key Interactions"
    echo "   2a. Reuse/Recover/Create Operator Key"
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
    echo -e "Topaz Valoper Candidates: ${BLUE}https://topaz.testnets.gno.land/r/gnops/valopers${RESET}"
    echo -e "${GREEN}Let's Buidl Gnoland Together - Grand Valley${RESET}"
    if ! read -r -p "Choose an option: " choice; then
        echo
        echo "Let's Buidl Gnoland Together - Grand Valley"
        exit 0
    fi
    case "${choice,,}" in
        1a|1-a) deploy_gnoland_node ;;
        1b|1-b) update_gnoland_binary ;;
        1c|1-c) apply_snapshot ;;
        1d|1-d) add_peers ;;
        1e|1-e) show_node_status ;;
        1f|1-f) show_logs ;;
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
