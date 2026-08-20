        add_result "config" "persistent_peers" "PASS" "Persistent peers include an official Sapphire peer" "$persistent_peers"
    else
        add_result "config" "persistent_peers" "WARN" \
            "Persistent peers are custom and contain no official Sapphire peer" \
            "$persistent_peers" \
            "Verify every peer ID and host, or restore the official Sapphire peers."
    fi

    RPC_LADDR=$(toml_get "rpc" "laddr")
    P2P_LADDR=$(toml_get "p2p" "laddr")
    PROXY_APP=$(toml_get "" "proxy_app")
    RPC_PORT=$(address_port "$RPC_LADDR")
    P2P_PORT=$(address_port "$P2P_LADDR")
    ABCI_PORT=$(address_port "$PROXY_APP")
    rpc_host=$(address_host "$RPC_LADDR")
    proxy_host=$(address_host "$PROXY_APP")

    if [ -n "$RPC_PORT" ] && is_loopback_host "$rpc_host"; then
        add_result "security" "rpc_bind" "PASS" "RPC is bound to a loopback address" "$RPC_LADDR"
    else
        add_result "security" "rpc_bind" "FAIL" \
            "RPC is missing or exposed beyond loopback" \
            "rpc.laddr=${RPC_LADDR:-missing}" \
            "Bind RPC to tcp://127.0.0.1:<rpc-port> and expose it only through an authenticated reverse proxy when required."
    fi

    if [ -n "$ABCI_PORT" ] && is_loopback_host "$proxy_host"; then
        add_result "security" "abci_bind" "PASS" "ABCI proxy is bound to loopback" "$PROXY_APP"
    else
        add_result "security" "abci_bind" "FAIL" \
            "ABCI proxy is missing or exposed beyond loopback" \
            "proxy_app=${PROXY_APP:-missing}" \
            "Bind proxy_app to tcp://127.0.0.1:<abci-port>."
    fi

    if [ -n "$P2P_PORT" ]; then
        add_result "config" "p2p_listener" "PASS" "P2P listener is configured" "$P2P_LADDR"
    else
        add_result "config" "p2p_listener" "FAIL" "P2P listener is missing or malformed" "p2p.laddr=${P2P_LADDR:-missing}"
    fi

    if [ -n "${GNOLAND_PORT:-}" ] && [[ "$GNOLAND_PORT" =~ ^[0-9]{2}$ ]]; then
        expected_rpc="${GNOLAND_PORT}657"
        expected_p2p="${GNOLAND_PORT}656"
        expected_abci="${GNOLAND_PORT}658"
        if [ "$RPC_PORT" = "$expected_rpc" ] && [ "$P2P_PORT" = "$expected_p2p" ] && [ "$ABCI_PORT" = "$expected_abci" ]; then
            add_result "config" "port_prefix" "PASS" "Configured ports match GNOLAND_PORT" "ABCI=$ABCI_PORT; P2P=$P2P_PORT; RPC=$RPC_PORT"
        else
            add_result "config" "port_prefix" "FAIL" \
                "Port-prefix drift detected" \
                "Observed ABCI=${ABCI_PORT:-missing}, P2P=${P2P_PORT:-missing}, RPC=${RPC_PORT:-missing}; expected $expected_abci/$expected_p2p/$expected_rpc" \
                "Review config.toml and the service before changing any listener on an active validator."
        fi
    elif [ -n "$RPC_PORT" ] && [ -n "$P2P_PORT" ] && [ -n "$ABCI_PORT" ] &&
         [ "$RPC_PORT" != "$P2P_PORT" ] && [ "$RPC_PORT" != "$ABCI_PORT" ] && [ "$P2P_PORT" != "$ABCI_PORT" ]; then
        add_result "config" "port_layout" "PASS" "ABCI, P2P, and RPC use distinct ports" "ABCI=$ABCI_PORT; P2P=$P2P_PORT; RPC=$RPC_PORT"
    else
        add_result "config" "port_layout" "FAIL" "Listener ports are missing or collide" "ABCI=${ABCI_PORT:-missing}; P2P=${P2P_PORT:-missing}; RPC=${RPC_PORT:-missing}"
    fi
}

check_live_network() {
    local rpc_url local_status network_status net_info local_network local_height network_height catching_up latest_block_time
    local public_network lag peer_count block_epoch now_epoch block_age listeners

    if [ -z "$RPC_PORT" ]; then
        add_result "network" "local_rpc" "FAIL" "Local RPC port could not be determined from config"
        return
    fi
    if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
