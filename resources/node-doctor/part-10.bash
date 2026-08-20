            add_result "network" "peer_count" "FAIL" "Node has no connected peers" "Peers=0"
        elif [ "$peer_count" -lt 3 ]; then
            add_result "network" "peer_count" "WARN" "Node has a low peer count" "Peers=$peer_count"
        else
            add_result "network" "peer_count" "PASS" "Node has connected peers" "Peers=$peer_count"
        fi
    else
        add_result "network" "peer_count" "WARN" "Peer count is unavailable from local RPC"
    fi

    if $OFFLINE_MODE; then
        add_result "network" "public_rpc" "WARN" "Public Sapphire RPC comparison was skipped by --offline"
    else
        network_status=$(curl -fsS --max-time 8 "${GNOLAND_PUBLIC_REMOTE%/}/status" 2>/dev/null || true)
        public_network=$(printf '%s' "$network_status" | jq -r '.result.node_info.network // empty' 2>/dev/null)
        network_height=$(printf '%s' "$network_status" | jq -r '.result.sync_info.latest_block_height // empty' 2>/dev/null)

        if [ "$public_network" = "$EXPECTED_CHAIN_ID" ]; then
            add_result "network" "public_rpc_chain_id" "PASS" "Public comparison RPC reports the Sapphire chain ID" "$public_network"
        elif [ -n "$public_network" ]; then
            add_result "network" "public_rpc_chain_id" "FAIL" \
                "Public comparison RPC reports the wrong network" \
                "Observed $public_network; expected $EXPECTED_CHAIN_ID; remote=$GNOLAND_PUBLIC_REMOTE" \
                "Correct GNOLAND_PUBLIC_REMOTE before trusting height comparisons."
        else
            add_result "network" "public_rpc_chain_id" "WARN" \
                "Public comparison RPC chain ID is unavailable" \
                "$GNOLAND_PUBLIC_REMOTE"
        fi

        if [ "$public_network" != "$EXPECTED_CHAIN_ID" ]; then
            add_result "network" "block_lag" "WARN" \
                "Block-lag comparison was skipped because the public RPC identity is unverified" \
                "Remote=${GNOLAND_PUBLIC_REMOTE}; reported network=${public_network:-unavailable}"
        elif [[ "$network_height" =~ ^[0-9]+$ ]] && [[ "$local_height" =~ ^[0-9]+$ ]]; then
            lag=$((network_height - local_height))
            [ "$lag" -lt 0 ] && lag=0
            if [ "$lag" -ge "$FAIL_BLOCK_LAG" ]; then
                add_result "network" "block_lag" "FAIL" "Node is far behind the public Sapphire RPC" "Local=$local_height; network=$network_height; lag=$lag"
            elif [ "$lag" -ge "$WARN_BLOCK_LAG" ]; then
                add_result "network" "block_lag" "WARN" "Node is behind the public Sapphire RPC" "Local=$local_height; network=$network_height; lag=$lag"
            else
                add_result "network" "block_lag" "PASS" "Node height is close to the public Sapphire RPC" "Local=$local_height; network=$network_height; lag=$lag"
            fi
        else
            add_result "network" "block_lag" "WARN" \
                "Public Sapphire RPC height is unavailable" \
                "$GNOLAND_PUBLIC_REMOTE" \
                "Retry later or compare against another trusted Sapphire RPC."
        fi
    fi

    if command -v ss >/dev/null 2>&1; then
        listeners=$(ss -H -ltn "sport = :$RPC_PORT" 2>/dev/null || true)
        if [ -z "$listeners" ]; then
            add_result "security" "rpc_listener" "FAIL" "No TCP listener was found on the configured RPC port" "Port=$RPC_PORT"
        elif printf '%s\n' "$listeners" | awk '{print $4}' | grep -Eq '(^|\[)(0\.0\.0\.0|\*|::)(\]|):'; then
            add_result "security" "rpc_listener" "FAIL" \
                "The live RPC listener appears publicly bound" \
                "$listeners" \
                "Bind RPC to 127.0.0.1 and verify firewall/reverse-proxy rules."
        else
