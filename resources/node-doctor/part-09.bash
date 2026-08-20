        add_result "network" "local_rpc" "FAIL" "curl or jq is unavailable; RPC health cannot be checked"
        return
    fi

    rpc_url="http://127.0.0.1:${RPC_PORT}"
    local_status=$(curl -fsS --max-time 5 "${rpc_url}/status" 2>/dev/null || true)
    if [ -z "$local_status" ]; then
        add_result "network" "local_rpc" "FAIL" \
            "Local RPC is unreachable" \
            "${rpc_url}/status" \
            "Inspect the service and its last 100 journal lines before restarting."
        return
    fi
    if ! printf '%s' "$local_status" | jq -e '.result.node_info.network and .result.sync_info.latest_block_height' >/dev/null 2>&1; then
        add_result "network" "local_rpc" "FAIL" "Local RPC returned an unexpected payload" "${rpc_url}/status"
        return
    fi
    add_result "network" "local_rpc" "PASS" "Local RPC is responding" "$rpc_url"

    local_network=$(printf '%s' "$local_status" | jq -r '.result.node_info.network // empty')
    local_height=$(printf '%s' "$local_status" | jq -r '.result.sync_info.latest_block_height // empty')
    catching_up=$(printf '%s' "$local_status" | jq -r 'if .result.sync_info.catching_up == null then empty else .result.sync_info.catching_up end')
    latest_block_time=$(printf '%s' "$local_status" | jq -r '.result.sync_info.latest_block_time // empty')

    if [ "$local_network" = "$EXPECTED_CHAIN_ID" ]; then
        add_result "network" "chain_id" "PASS" "Local RPC reports the Sapphire chain ID" "$local_network"
    else
        add_result "network" "chain_id" "FAIL" \
            "Local RPC reports the wrong network" \
            "Observed ${local_network:-missing}; expected $EXPECTED_CHAIN_ID" \
            "Do not operate this instance as Sapphire until its data and service are verified."
    fi

    if [ "$catching_up" = "false" ]; then
        add_result "network" "catching_up" "PASS" "Node reports catching_up=false" "Height=$local_height"
    elif [ "$catching_up" = "true" ]; then
        add_result "network" "catching_up" "WARN" "Node is still catching up" "Height=$local_height"
    else
        add_result "network" "catching_up" "WARN" "RPC did not report a recognised catching_up value" "$catching_up"
    fi

    if [ -n "$latest_block_time" ]; then
        block_epoch=$(date -d "$latest_block_time" +%s 2>/dev/null || true)
        now_epoch=$(date +%s)
        if [[ "$block_epoch" =~ ^[0-9]+$ ]]; then
            block_age=$((now_epoch - block_epoch))
            [ "$block_age" -lt 0 ] && block_age=0
            if [ "$block_age" -ge "$FAIL_BLOCK_AGE_SECONDS" ]; then
                add_result "network" "latest_block_age" "WARN" \
                    "Latest local block is stale" \
                    "Age=${block_age}s; block_time=$latest_block_time" \
                    "Compare with trusted network status before assuming the local node is at fault; the testnet itself may be halted."
            elif [ "$block_age" -ge "$WARN_BLOCK_AGE_SECONDS" ]; then
                add_result "network" "latest_block_age" "WARN" "Latest local block is older than expected" "Age=${block_age}s; block_time=$latest_block_time"
            else
                add_result "network" "latest_block_age" "PASS" "Latest local block is recent" "Age=${block_age}s"
            fi
        else
            add_result "network" "latest_block_age" "WARN" "Latest block time could not be parsed" "$latest_block_time"
        fi
    else
        add_result "network" "latest_block_age" "WARN" "Local RPC did not report latest_block_time"
    fi

    net_info=$(curl -fsS --max-time 5 "${rpc_url}/net_info" 2>/dev/null || true)
    peer_count=$(printf '%s' "$net_info" | jq -r '.result.n_peers // empty' 2>/dev/null)
    if [[ "$peer_count" =~ ^[0-9]+$ ]]; then
        if [ "$peer_count" -eq 0 ]; then
