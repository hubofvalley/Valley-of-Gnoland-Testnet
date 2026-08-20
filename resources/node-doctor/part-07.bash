        add_result "artifacts" "genesis" "FAIL" "Sapphire genesis file is missing" "$GNOLAND_GENESIS"
    fi

    resolved=$(command -v gnoland 2>/dev/null || true)
    if [ "$resolved" = "$GNOLAND_BIN" ]; then
        add_result "artifacts" "command_resolution" "PASS" "gnoland resolves to the managed per-user binary" "$resolved"
    else
        add_result "artifacts" "command_resolution" "WARN" \
            "gnoland command resolves to a different path" \
            "Observed ${resolved:-unavailable}; expected $GNOLAND_BIN" \
            "Review PATH before manual node operations."
    fi
}

RPC_LADDR=""
P2P_LADDR=""
PROXY_APP=""
RPC_PORT=""
P2P_PORT=""
ABCI_PORT=""
check_config() {
    local persistent_peers seeds mempool_size outbound_peers rpc_host proxy_host expected_rpc expected_p2p expected_abci

    if [ ! -f "$CONFIG_FILE" ]; then
        add_result "config" "config_file" "FAIL" \
            "Gnoland config file is missing" \
            "$CONFIG_FILE" \
            "Deploy the node before running configuration drift checks."
        return
    fi
    add_result "config" "config_file" "PASS" "Gnoland config file is present" "$CONFIG_FILE"

    config_drift_check "application" "prune_strategy" "syncable" "FAIL" "prune_strategy"
    config_drift_check "consensus" "timeout_commit" "3s" "FAIL" "timeout_commit"
    config_drift_check "consensus" "peer_gossip_sleep_duration" "10ms" "FAIL" "peer_gossip_sleep_duration"
    config_drift_check "p2p" "flush_throttle_timeout" "10ms" "FAIL" "flush_throttle_timeout"
    config_drift_check "p2p" "pex" "true" "WARN" "peer_exchange"

    mempool_size=$(toml_get "mempool" "size")
    if [ "$mempool_size" = "10000" ]; then
        add_result "config" "mempool_size" "PASS" "Mempool size matches the advised Sapphire value" "mempool.size=$mempool_size"
    else
        add_result "config" "mempool_size" "WARN" \
            "Mempool size differs from the advised Sapphire value" \
            "mempool.size=${mempool_size:-missing}; advised 10000" \
            "Review before changing: gnoland config set -config-path '$CONFIG_FILE' 'mempool.size' '10000'."
    fi

    outbound_peers=$(toml_get "p2p" "max_num_outbound_peers")
    if [ "$outbound_peers" = "40" ]; then
        add_result "config" "outbound_peer_limit" "PASS" "Outbound peer limit matches the advised Sapphire value" "p2p.max_num_outbound_peers=$outbound_peers"
    else
        add_result "config" "outbound_peer_limit" "WARN" \
            "Outbound peer limit differs from the advised Sapphire value" \
            "p2p.max_num_outbound_peers=${outbound_peers:-missing}; advised 40"
    fi

    seeds=$(toml_get "p2p" "seeds")
    if [ -z "$seeds" ]; then
        add_result "config" "p2p_seeds" "PASS" "p2p.seeds is empty as expected"
    else
        add_result "config" "p2p_seeds" "WARN" \
            "p2p.seeds is populated but Gnoland uses persistent peers" \
            "$seeds" \
            "Move intended peers to p2p.persistent_peers and clear p2p.seeds after review."
    fi

    persistent_peers=$(toml_get "p2p" "persistent_peers")
    if [ -z "$persistent_peers" ]; then
        add_result "config" "persistent_peers" "FAIL" \
            "No persistent peers are configured" \
            "p2p.persistent_peers is empty" \
            "Restore verified Sapphire persistent peers before restarting."
    elif [ "$persistent_peers" = "$EXPECTED_PERSISTENT_PEERS" ]; then
        add_result "config" "persistent_peers" "PASS" "Official Sapphire persistent peers are configured"
    elif [[ ",$persistent_peers," == *",${EXPECTED_PERSISTENT_PEERS%%,*},"* ]] ||
         [[ ",$persistent_peers," == *",${EXPECTED_PERSISTENT_PEERS##*,},"* ]]; then
