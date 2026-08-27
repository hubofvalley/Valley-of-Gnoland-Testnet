#!/bin/bash

set -u -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
ORANGE='\033[38;5;214m'
RESET='\033[0m'

# Runtime-downloaded executable helpers are pinned to an immutable reviewed commit.
readonly VALLEY_RUNTIME_REF="3988d923ab35e8ed7fd1acc0d006c77b8b138240"
NODE_DOCTOR_RELATIVE_PATH="resources/gnoland_node_doctor.sh"

run_node_doctor_script() {
    local script_dir script_file exit_code
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
    if [ -n "$script_dir" ] && [ -f "$script_dir/gnoland_node_doctor.sh" ]; then
        GNOLAND_NODE_DOCTOR_REF="$VALLEY_RUNTIME_REF" bash "$script_dir/gnoland_node_doctor.sh" "$@"
        return $?
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}curl is required to download the Node Doctor.${RESET}" >&2
        return 2
    fi
    script_file=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/${VALLEY_RUNTIME_REF}/${NODE_DOCTOR_RELATIVE_PATH}" -o "$script_file"; then
        rm -f "$script_file"
        echo -e "${RED}Failed to download the Node Doctor from pinned commit ${VALLEY_RUNTIME_REF}. Nothing was executed.${RESET}" >&2
        return 2
    fi
    chmod +x "$script_file"
    GNOLAND_NODE_DOCTOR_REF="$VALLEY_RUNTIME_REF" bash "$script_file" "$@"
    exit_code=$?
    rm -f "$script_file"
    return "$exit_code"
}

if [ "${1:-}" = "doctor" ] || [ "${1:-}" = "node-doctor" ]; then
    shift
    run_node_doctor_script "$@"
    exit $?
fi

# shellcheck source=/dev/null
source "$HOME/.bash_profile" 2>/dev/null || true

OS_USER=$(id -un)
if [ -n "${SUDO_USER:-}" ]; then
    echo -e "${RED}Run Valley of Gnoland as the node OS user, not with sudo.${RESET}" >&2
    exit 1
fi

GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_HOME=${GNOLAND_HOME:-$GNO_SOURCE_DIR/gnoland-data}
GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$GNO_SOURCE_DIR/genesis.json}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
GNOLAND_CHAIN_ID=${GNOLAND_CHAIN_ID:-pearl-1}
GNOLAND_PUBLIC_REMOTE=${GNOLAND_PUBLIC_REMOTE:-https://rpc.pearl.testnets.gno.land}
GNOLAND_REMOTE=${GNOLAND_REMOTE:-http://127.0.0.1:26657}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
export GNOROOT
export PATH="$HOME/go/bin:$PATH"

readonly OFFICIAL_PEARL_PEERS="g1m37xukfq6yl555k93fcyzns83qnmgyax9zm875@seed-1.pearl.testnets.gno.land:26656,g1ngukqd3khekaqjf90k45cglzm0l25wwzl2fkn2@seed-2.pearl.testnets.gno.land:26656"
readonly PEARL_GENESIS_SHA256="c45fe60c8c8a1f859d9e4d5aad7ce4d100ff0eb78302e71318ba0de481a8dc91"
readonly VALOPER_GAS_WANTED=50000000

if [[ ! "$GNOLAND_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
    echo -e "${RED}Invalid GNOLAND_SERVICE_NAME: $GNOLAND_SERVICE_NAME${RESET}" >&2
    exit 1
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

ENDPOINTS="${GREEN}
Gno.land Pearl useful links:${RESET}
- Official Docs: ${BLUE}https://docs.gno.land/${RESET}
- Pearl Release: ${BLUE}https://github.com/gnolang/gno/releases/tag/chain/pearl${RESET}
- Pearl Validator Guide: ${BLUE}https://github.com/gnolang/gno/blob/chain/pearl/misc/deployments/pearl.gno.land/VALIDATOR.md${RESET}
- Faucet: ${BLUE}https://pearl.testnets.gno.land/faucet${RESET}
- Valoper Candidates: ${BLUE}https://pearl.testnets.gno.land/r/gnops/valopers${RESET}
- Active Validators Realm: ${BLUE}https://pearl.testnets.gno.land/r/sys/validators/v3${RESET}

${GREEN}Network facts:${RESET}
- Chain ID: ${CYAN}pearl-1${RESET}
- RPC: ${CYAN}https://rpc.pearl.testnets.gno.land${RESET}
- Official persistent peers: ${CYAN}${OFFICIAL_PEARL_PEERS}${RESET}
- Genesis SHA256: ${CYAN}${PEARL_GENESIS_SHA256}${RESET}

${GREEN}Connect with Grand Valley:${RESET}
- X: ${BLUE}https://x.com/bacvalley${RESET}
- GitHub: ${BLUE}https://github.com/hubofvalley${RESET}
- Email: ${BLUE}letsbuidltogether@grandvalleys.com${RESET}
"

service_belongs_to_current_instance() {
    local service_file unit_user unit_workdir
    service_file=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
    [ -n "$service_file" ] || return 0
    [ -f "$service_file" ] || { echo -e "${RED}Cannot inspect existing service: $service_file${RESET}" >&2; return 1; }
    unit_user=$(sed -n 's/^User=//p' "$service_file" | tail -n 1)
    unit_workdir=$(sed -n 's/^WorkingDirectory=//p' "$service_file" | tail -n 1)
    if [ "$unit_user" != "$OS_USER" ] || [ "$unit_workdir" != "$GNO_SOURCE_DIR" ]; then
        echo -e "${RED}${GNOLAND_SERVICE_NAME}.service belongs to another instance.${RESET}" >&2
        echo "Existing User=${unit_user:-unknown}, WorkingDirectory=${unit_workdir:-unknown}" >&2
        return 1
    fi
}

function run_repository_script() {
    local relative_path=$1
    local script_dir script_file exit_code
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
    if [ -n "$script_dir" ] && [ -f "$script_dir/$(basename "$relative_path")" ]; then
        bash "$script_dir/$(basename "$relative_path")"
        return $?
    fi
    script_file=$(mktemp)
    if ! curl -fsSL "https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/${VALLEY_RUNTIME_REF}/${relative_path}" -o "$script_file"; then
        rm -f "$script_file"
        echo -e "${RED}Failed to download ${relative_path} from pinned commit ${VALLEY_RUNTIME_REF}. Nothing was executed.${RESET}" >&2
        return 1
    fi
    chmod +x "$script_file"
    bash "$script_file"
    exit_code=$?
    rm -f "$script_file"
    return "$exit_code"
}

get_local_rpc_url() {
    local cfg="$GNOLAND_HOME/config/config.toml" port=""
    if [ -f "$cfg" ]; then
        port=$(awk -F: '/^[[:space:]]*\[rpc\][[:space:]]*$/ {in_rpc=1; next} /^[[:space:]]*\[/ {in_rpc=0} in_rpc && /^[[:space:]]*laddr = "tcp:\/\// {gsub(/".*/, "", $NF); print $NF; exit}' "$cfg")
    fi
    if [ -n "$port" ]; then printf 'http://127.0.0.1:%s\n' "$port"; else printf '%s\n' "$GNOLAND_REMOTE"; fi
}

get_local_status_json() { curl -m 5 -s "$(get_local_rpc_url)/status" 2>/dev/null || true; }
get_network_height() { curl -m 5 -s "$GNOLAND_PUBLIC_REMOTE/status" 2>/dev/null | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null || true; }
pause_menu() { echo -e "\n${YELLOW}Press Enter to return to the menu.${RESET}"; read -r || true; }

deploy_gnoland_node() {
    clear
    echo -e "${CYAN}Sapphire -> Pearl migration / Pearl fresh install${RESET}"
    echo "Pearl is a new chain; Sapphire db/wal state is not reused."
    echo "The installer backs up node secrets and the operator keyring, then creates fresh Pearl node secrets."
    echo "Reusing the Sapphire operator key is optional address continuity and does not preserve validator status."
    read -r -p "Proceed? Type yes: " confirm
    if [ "${confirm,,}" = "yes" ]; then run_repository_script "resources/gnoland_node_install_testnet.sh" || true; fi
    pause_menu
}

update_gnoland_binary() {
    echo -e "${YELLOW}Update gnoland and gnokey to the pinned Pearl release.${RESET}"
    echo "This updater refuses non-Pearl services; use Deploy/Re-deploy for Sapphire -> Pearl migration."
    read -r -p "Proceed? Type yes: " confirm
    if [ "${confirm,,}" = "yes" ] && service_belongs_to_current_instance; then run_repository_script "resources/gnoland_update.sh" || true; fi
    pause_menu
}

apply_snapshot() {
    echo -e "${YELLOW}Pearl snapshots are currently fail-closed.${RESET}"
    run_repository_script "resources/apply_snapshot.sh" || true
    pause_menu
}

add_peers() {
    local cfg="$GNOLAND_HOME/config/config.toml" choice peers
    [ -f "$cfg" ] || { echo -e "${RED}config.toml not found at $cfg.${RESET}"; pause_menu; return; }
    echo "1. Add peers manually"
    echo "2. Reset to official Pearl persistent peers"
    echo "3. Back"
    read -r -p "Choice: " choice
    case "$choice" in
        1) read -r -p "Peers (comma-separated id@host:port): " peers; "$GNOLAND_BIN" config set -config-path "$cfg" p2p.persistent_peers "$peers" ;;
        2) "$GNOLAND_BIN" config set -config-path "$cfg" p2p.seeds ""; "$GNOLAND_BIN" config set -config-path "$cfg" p2p.persistent_peers "$OFFICIAL_PEARL_PEERS"; echo "Official Pearl persistent peers restored." ;;
        3) return ;;
        *) echo "Invalid choice." ;;
    esac
    echo "Restart the node to apply peer changes."
    pause_menu
}

show_node_status() {
    local status network node_height network_height catching_up peer_count rpc_url
    rpc_url=$(get_local_rpc_url)
    status=$(get_local_status_json)
    network=$(printf '%s' "$status" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
    node_height=$(printf '%s' "$status" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null || true)
    catching_up=$(printf '%s' "$status" | jq -r '.result.sync_info.catching_up // empty' 2>/dev/null || true)
    network_height=$(get_network_height)
    peer_count=$(curl -m 5 -s "${rpc_url%/}/net_info" 2>/dev/null | jq -r '.result.n_peers // empty' 2>/dev/null || true)
    echo "Service: ${GNOLAND_SERVICE_NAME}.service ($(systemctl is-active "$GNOLAND_SERVICE_NAME" 2>/dev/null || true))"
    echo "Local RPC: $rpc_url"
    echo "Network: ${network:-unavailable} (expected pearl-1)"
    echo "Local height: ${node_height:-unavailable}"
    echo "Pearl height: ${network_height:-unavailable}"
    echo "Catching up: ${catching_up:-unavailable}"
    echo "Connected peers: ${peer_count:-unavailable}"
    pause_menu
}

show_logs() { if service_belongs_to_current_instance; then sudo journalctl -u "$GNOLAND_SERVICE_NAME" -fn 100 -o cat || true; fi; }
run_node_doctor() { run_node_doctor_script || true; pause_menu; }
operator_key_exists() { "$GNOKEY_BIN" -home "$GNOKEY_HOME" list 2>/dev/null | awk -v key="$1" '$2 == key {found=1} END {exit !found}'; }

create_operator_key() {
    local choice keyname
    echo "1. List/reuse an existing Sapphire operator key"
    echo "2. Recover an existing Sapphire operator key from mnemonic"
    echo "3. Create a new Pearl operator key"
    echo "4. Back"
    read -r -p "Choice: " choice
    case "$choice" in
        1) echo -e "${YELLOW}Reusing a key preserves only the operator address; Pearl validator admission is new.${RESET}"; "$GNOKEY_BIN" -home "$GNOKEY_HOME" list ;;
        2) read -r -p "Key name (default operator): " keyname; keyname=${keyname:-operator}; operator_key_exists "$keyname" && echo "Key already exists; refusing overwrite." || "$GNOKEY_BIN" -home "$GNOKEY_HOME" add -recover "$keyname" ;;
        3) read -r -p "Key name (default operator): " keyname; keyname=${keyname:-operator}; operator_key_exists "$keyname" && echo "Key already exists; refusing overwrite." || "$GNOKEY_BIN" -home "$GNOKEY_HOME" add "$keyname" ;;
        4) return ;;
        *) echo "Invalid choice." ;;
    esac
    echo "Pearl faucet: https://pearl.testnets.gno.land/faucet"
    pause_menu
}

show_validator_pubkey() {
    (cd "$GNO_SOURCE_DIR" && "$GNOLAND_BIN" secrets get validator_key)
    echo "Use the gpub1... value for Pearl valoper candidate registration."
    pause_menu
}

register_valoper_candidate() {
    local key_name moniker description infra_type operator_addr consensus_pubkey confirm
    echo -e "${CYAN}Register Pearl valoper candidate${RESET}"
    echo "This broadcasts a transaction. It does not directly add the node to the active validator set."
    read -r -p "Operator key name (default operator): " key_name
    key_name=${key_name:-operator}
    read -r -p "Validator moniker: " moniker
    read -r -p "Short description: " description
    read -r -p "Infrastructure type (cloud/on-prem/data-center): " infra_type
    read -r -p "Operator g1... address: " operator_addr
    read -r -p "Consensus gpub1... public key: " consensus_pubkey
    echo
    echo "Package: gno.land/r/gnops/valopers"
    echo "Function: Register"
    echo "Chain: pearl-1"
    echo "Gas fee: 1000000ugnot | gas wanted: $VALOPER_GAS_WANTED"
    read -r -p "Broadcast? Type yes: " confirm
    if [ "${confirm,,}" != "yes" ]; then echo "Cancelled."; pause_menu; return; fi
    "$GNOKEY_BIN" -home "$GNOKEY_HOME" -remote "$GNOLAND_PUBLIC_REMOTE" maketx call \
        --pkgpath gno.land/r/gnops/valopers \
        --func Register \
        --args "$moniker" \
        --args "$description" \
        --args "$infra_type" \
        --args "$operator_addr" \
        --args "$consensus_pubkey" \
        --gas-fee 1000000ugnot \
        --gas-wanted "$VALOPER_GAS_WANTED" \
        --chainid "$GNOLAND_CHAIN_ID" \
        --broadcast \
        "$key_name" || true
    echo "Next gate: a GovDAO member must create and pass a proposal through r/sys/validators/v3."
    pause_menu
}

query_balance_or_realm() {
    local choice path
    echo "1. Query account/ABCI path manually"
    echo "2. Show Pearl valoper URLs"
    echo "3. Back"
    read -r -p "Choice: " choice
    case "$choice" in
        1) read -r -p "ABCI query path: " path; "$GNOKEY_BIN" -home "$GNOKEY_HOME" -remote "$GNOLAND_PUBLIC_REMOTE" query "$path" || true ;;
        2) echo "Candidates: https://pearl.testnets.gno.land/r/gnops/valopers"; echo "Active validators: https://pearl.testnets.gno.land/r/sys/validators/v3" ;;
        3) return ;;
        *) echo "Invalid choice." ;;
    esac
    pause_menu
}

restart_gnoland() { service_belongs_to_current_instance && sudo systemctl restart "$GNOLAND_SERVICE_NAME"; pause_menu; }
stop_gnoland() { service_belongs_to_current_instance && sudo systemctl stop "$GNOLAND_SERVICE_NAME"; pause_menu; }

backup_node_secrets() {
    local backup
    if [ -d "$GNOLAND_HOME/secrets" ]; then
        backup="$HOME/gnoland-pearl-secrets-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$backup" -C "$GNOLAND_HOME" secrets
        chmod 600 "$backup"
        echo "Node secrets backed up to $backup"
    else
        echo "No node secrets found at $GNOLAND_HOME/secrets"
    fi
    pause_menu
}

delete_gnoland_node() {
    local confirm canonical_home canonical_node_home
    echo -e "${RED}This deletes Pearl node data, service, and per-user binaries. It keeps $GNOKEY_HOME.${RESET}"
    read -r -p "Type DELETE-PEARL-NODE to continue: " confirm
    [ "$confirm" = "DELETE-PEARL-NODE" ] || return
    service_belongs_to_current_instance || return
    canonical_home=$(realpath -m "$HOME")
    canonical_node_home=$(realpath -m "$GNOLAND_HOME")
    case "$canonical_node_home" in "$canonical_home"/*) ;; *) echo "Unsafe node path."; return 1 ;; esac
    sudo systemctl stop "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
    sudo systemctl disable "$GNOLAND_SERVICE_NAME" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/${GNOLAND_SERVICE_NAME}.service"
    sudo systemctl daemon-reload
    rm -rf "$GNOLAND_HOME"
    rm -f "$GNOLAND_GENESIS" "$GNOLAND_BIN" "$GNOKEY_BIN"
    sed -i '/GNOLAND_/d;/GNOKEY_/d;/GNO_SOURCE_DIR/d;/GNOROOT/d;/go\/bin/d' "$HOME/.bash_profile" 2>/dev/null || true
    echo "Pearl node deleted. Operator keyring preserved at $GNOKEY_HOME"
    pause_menu
}

show_guidelines() {
    cat <<'GUIDE'
Recommended Pearl flow:
  1. Deploy/Re-deploy: this is also the Sapphire -> Pearl migration path.
  2. Wait for pearl-1 to sync.
  3. Reuse/recover a Sapphire operator key only if you want the same g1 address, or create a new key.
  4. Fund the operator address from the Pearl faucet.
  5. Read the fresh Pearl consensus gpub1... key.
  6. Register a valoper candidate.
  7. Wait for separate GovDAO proposal approval before expecting active validator status.

Sapphire db/wal, consensus state, and snapshots are never reused on Pearl.
Pearl snapshots remain disabled until a provider is explicitly reviewed and pinned.
GUIDE
    pause_menu
}

menu() {
    clear
    echo -e "$LOGO"
    local status node_height network_height network
    status=$(get_local_status_json)
    node_height=$(printf '%s' "$status" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null || true)
    network=$(printf '%s' "$status" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
    network_height=$(get_network_height)
    echo -e "${GREEN}Valley of Gnoland by ${ORANGE}Grand Valley${RESET}"
    echo "Target network: Pearl (pearl-1) | Local network: ${network:-N/A} | Local height: ${node_height:-N/A} | Pearl height: ${network_height:-N/A}"
    echo
    echo "1. Node Interactions"
    echo "   1a. Deploy/Re-deploy Gnoland Node (Sapphire -> Pearl migration)"
    echo "   1b. Update Pearl Gnoland/Gnokey Binaries"
    echo "   1c. Apply Snapshot (disabled until Pearl provider is verified)"
    echo "   1d. Add/Reset Pearl Peers"
    echo "   1e. Show Node Status"
    echo "   1f. Show Node Logs"
    echo "   1g. Run Node Doctor (read-only Pearl checks)"
    echo
    echo "2. Validator/Key Interactions"
    echo "   2a. Reuse/Recover/Create Operator Key"
    echo "   2b. Show Validator Consensus Pubkey"
    echo "   2c. Register Pearl Valoper Candidate"
    echo "   2d. Query / Show Valoper Pages"
    echo
    echo "3. Node Management"
    echo "   3a. Restart Gnoland Node"
    echo "   3b. Stop Gnoland Node"
    echo "   3c. Delete Gnoland Node"
    echo "   3d. Backup Pearl Node Secrets"
    echo
    echo "4. Show Pearl Endpoints & Useful Links"
    echo "5. Show Guidelines"
    echo "6. Exit"
    echo
    echo -e "Pearl Valoper Candidates: ${BLUE}https://pearl.testnets.gno.land/r/gnops/valopers${RESET}"
    read -r -p "Choose an option: " choice || exit 0
    case "${choice,,}" in
        1a|1-a) deploy_gnoland_node ;;
        1b|1-b) update_gnoland_binary ;;
        1c|1-c) apply_snapshot ;;
        1d|1-d) add_peers ;;
        1e|1-e) show_node_status ;;
        1f|1-f) show_logs ;;
        1g|1-g) run_node_doctor ;;
        2a|2-a) create_operator_key ;;
        2b|2-b) show_validator_pubkey ;;
        2c|2-c) register_valoper_candidate ;;
        2d|2-d) query_balance_or_realm ;;
        3a|3-a) restart_gnoland ;;
        3b|3-b) stop_gnoland ;;
        3c|3-c) delete_gnoland_node ;;
        3d|3-d) backup_node_secrets ;;
        4) echo -e "$ENDPOINTS"; pause_menu ;;
        5) show_guidelines ;;
        6) echo "Let's Buidl Gnoland Together - Grand Valley"; exit 0 ;;
        *) echo "Invalid choice."; sleep 1 ;;
    esac
}

while true; do menu; done
