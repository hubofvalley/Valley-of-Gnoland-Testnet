#!/bin/bash

set -u -o pipefail

readonly DEFAULT_NODE_DOCTOR_REF="3988d923ab35e8ed7fd1acc0d006c77b8b138240"
readonly EXPECTED_CHAIN_ID="pearl-1"
readonly EXPECTED_RELEASE_COMMIT="c4c72fdd288c757e8da0d93aae867fa479b1b15c"
readonly EXPECTED_GENESIS_SHA256="c45fe60c8c8a1f859d9e4d5aad7ce4d100ff0eb78302e71318ba0de481a8dc91"
readonly EXPECTED_PEERS="g1m37xukfq6yl555k93fcyzns83qnmgyax9zm875@seed-1.pearl.testnets.gno.land:26656,g1ngukqd3khekaqjf90k45cglzm0l25wwzl2fkn2@seed-2.pearl.testnets.gno.land:26656"
readonly PUBLIC_RPC="https://rpc.pearl.testnets.gno.land"

NODE_DOCTOR_REF=${GNOLAND_NODE_DOCTOR_REF:-$DEFAULT_NODE_DOCTOR_REF}
if [[ ! "$NODE_DOCTOR_REF" =~ ^[0-9a-f]{40}$ ]]; then
    echo "Node Doctor loader failed: GNOLAND_NODE_DOCTOR_REF must be a full 40-character Git commit SHA." >&2
    exit 2
fi

if [ "${1:-}" = "--version" ]; then
    echo "Valley of Gnoland Node Doctor (Pearl) 1.0.0"
    exit 0
fi

JSON_MODE=false
STRICT_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --strict) STRICT_MODE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

profile_value() {
    local name=$1 default=$2 value=""
    if [ -f "$HOME/.bash_profile" ]; then
        value=$(sed -n "s/^export ${name}=\"\(.*\)\"$/\1/p" "$HOME/.bash_profile" | tail -n 1)
    fi
    printf '%s\n' "${value:-$default}"
}

GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$(profile_value GNO_SOURCE_DIR "$HOME/gno")}
GNOLAND_HOME=${GNOLAND_HOME:-$(profile_value GNOLAND_HOME "$GNO_SOURCE_DIR/gnoland-data")}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$(profile_value GNOLAND_GENESIS "$GNO_SOURCE_DIR/genesis.json")}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-$(profile_value GNOLAND_SERVICE_NAME "gnoland")}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
GNOLAND_REMOTE=${GNOLAND_REMOTE:-$(profile_value GNOLAND_REMOTE "http://127.0.0.1:26657")}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
CONFIG_FILE="$GNOLAND_HOME/config/config.toml"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
RESULTS=()

record() {
    local level=$1 code=$2 message=$3
    RESULTS+=("$level|$code|$message")
    case "$level" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac
}

if [ -x "$GNOLAND_BIN" ] && [ -x "$GNOKEY_BIN" ]; then
    record PASS binaries "gnoland and gnokey are executable under $HOME/go/bin"
else
    record FAIL binaries "Pearl binaries are missing or not executable under $HOME/go/bin"
fi

if [ -d "$GNO_SOURCE_DIR/.git" ]; then
    source_commit=$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)
    if [ "$source_commit" = "$EXPECTED_RELEASE_COMMIT" ]; then
        record PASS source_commit "source checkout matches pinned Pearl commit"
    else
        record FAIL source_commit "source checkout is ${source_commit:-unreadable}; expected $EXPECTED_RELEASE_COMMIT"
    fi
else
    record FAIL source_commit "Gno source checkout is missing at $GNO_SOURCE_DIR"
fi

if [ -f "$GNOLAND_GENESIS" ]; then
    genesis_sha=$(sha256sum "$GNOLAND_GENESIS" 2>/dev/null | awk '{print $1}')
    if [ "$genesis_sha" = "$EXPECTED_GENESIS_SHA256" ]; then
        record PASS genesis "Pearl genesis checksum matches the pinned release"
    else
        record FAIL genesis "genesis checksum mismatch: ${genesis_sha:-unreadable}"
    fi
else
    record FAIL genesis "genesis file is missing at $GNOLAND_GENESIS"
fi

if [ -f "$CONFIG_FILE" ]; then
    if grep -Fq "persistent_peers = \"$EXPECTED_PEERS\"" "$CONFIG_FILE"; then
        record PASS peers "official Pearl persistent peers are configured"
    else
        record WARN peers "persistent peers differ from the pinned Pearl defaults"
    fi
    grep -Fq 'prune_strategy = "syncable"' "$CONFIG_FILE" && record PASS prune "prune_strategy is syncable" || record FAIL prune "application.prune_strategy is not syncable"
    grep -Fq 'timeout_commit = "3s"' "$CONFIG_FILE" && record PASS timeout_commit "consensus timeout_commit is 3s" || record FAIL timeout_commit "consensus.timeout_commit is not 3s"
    grep -Fq 'peer_gossip_sleep_duration = "10ms"' "$CONFIG_FILE" && record PASS gossip "peer gossip sleep is 10ms" || record FAIL gossip "consensus.peer_gossip_sleep_duration is not 10ms"
    grep -Fq 'flush_throttle_timeout = "10ms"' "$CONFIG_FILE" && record PASS flush "P2P flush throttle is 10ms" || record FAIL flush "p2p.flush_throttle_timeout is not 10ms"
    grep -Fq 'pex = true' "$CONFIG_FILE" && record PASS pex "P2P exchange is enabled" || record WARN pex "p2p.pex is not enabled"
else
    record FAIL config "config.toml is missing at $CONFIG_FILE"
fi

service_file=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
if [ -n "$service_file" ] && [ -f "$service_file" ]; then
    grep -Fq -- '--chainid pearl-1' "$service_file" && record PASS service_chain "systemd starts pearl-1" || record FAIL service_chain "systemd does not start pearl-1"
    grep -Fq -- '--skip-genesis-sig-verification' "$service_file" && record PASS genesis_flag "required Pearl genesis signature-skip flag is present" || record FAIL genesis_flag "required --skip-genesis-sig-verification flag is missing"
else
    record FAIL service "systemd unit for ${GNOLAND_SERVICE_NAME}.service was not found"
fi

local_status=$(curl -m 5 -fsS "${GNOLAND_REMOTE%/}/status" 2>/dev/null || true)
local_network=$(printf '%s' "$local_status" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
if [ "$local_network" = "$EXPECTED_CHAIN_ID" ]; then
    record PASS local_rpc "local RPC reports $EXPECTED_CHAIN_ID"
elif [ -n "$local_network" ]; then
    record FAIL local_rpc "local RPC reports $local_network, expected $EXPECTED_CHAIN_ID"
else
    record WARN local_rpc "local RPC is not reachable at $GNOLAND_REMOTE"
fi

public_status=$(curl -m 5 -fsS "$PUBLIC_RPC/status" 2>/dev/null || true)
public_network=$(printf '%s' "$public_status" | jq -r '.result.node_info.network // empty' 2>/dev/null || true)
if [ "$public_network" = "$EXPECTED_CHAIN_ID" ]; then
    record PASS public_rpc "official Pearl RPC reports $EXPECTED_CHAIN_ID"
else
    record WARN public_rpc "official Pearl RPC was unavailable or reported an unexpected network"
fi

if command -v timedatectl >/dev/null 2>&1; then
    ntp_state=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)
    [ "$ntp_state" = "yes" ] && record PASS time_sync "system clock reports NTP synchronized" || record WARN time_sync "NTP synchronization could not be confirmed"
fi

if [ -d "$GNOLAND_HOME" ]; then
    free_kb=$(df -Pk "$GNOLAND_HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ "$free_kb" =~ ^[0-9]+$ ]] && [ "$free_kb" -lt 20971520 ]; then
        record WARN disk "less than 20 GiB free on the node filesystem"
    else
        record PASS disk "node filesystem has at least 20 GiB free or capacity was not constrained"
    fi
fi

if $JSON_MODE; then
    printf '{"network":"%s","runtime_ref":"%s","pass":%d,"warn":%d,"fail":%d,"results":[' "$EXPECTED_CHAIN_ID" "$NODE_DOCTOR_REF" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
    first=true
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r level code message <<<"$row"
        $first || printf ','
        first=false
        jq -cn --arg level "$level" --arg code "$code" --arg message "$message" '{level:$level,code:$code,message:$message}'
    done
    printf ']}\n'
else
    echo "Valley of Gnoland Node Doctor - Pearl"
    echo "Expected chain: $EXPECTED_CHAIN_ID"
    echo "Pinned release: $EXPECTED_RELEASE_COMMIT"
    echo
    for row in "${RESULTS[@]}"; do
        IFS='|' read -r level code message <<<"$row"
        printf '[%s] %-16s %s\n' "$level" "$code" "$message"
    done
    echo
    echo "Summary: PASS=$PASS_COUNT WARN=$WARN_COUNT FAIL=$FAIL_COUNT"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; fi
if $STRICT_MODE && [ "$WARN_COUNT" -gt 0 ]; then exit 1; fi
exit 0
