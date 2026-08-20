            add_result "security" "rpc_listener" "PASS" "Live RPC listener is not wildcard-bound" "$listeners"
        fi

        if [ -n "$P2P_PORT" ]; then
            listeners=$(ss -H -ltn "sport = :$P2P_PORT" 2>/dev/null || true)
            if [ -n "$listeners" ]; then
                add_result "network" "p2p_listener" "PASS" "Live P2P listener is present" "$listeners"
            else
                add_result "network" "p2p_listener" "FAIL" "No TCP listener was found on the configured P2P port" "Port=$P2P_PORT"
            fi
        fi
    else
        add_result "security" "live_listeners" "WARN" "ss is unavailable; live listener bindings were not checked"
    fi
}

check_firewall() {
    local output ufw_rc

    if ! command -v ufw >/dev/null 2>&1; then
        add_result "security" "host_firewall" "WARN" \
            "UFW is not installed; host-firewall state was not verified" \
            "RPC binding and live listeners were still inspected" \
            "Verify the active host or provider firewall independently."
        return
    fi

    if output=$(ufw status 2>&1); then
        ufw_rc=0
    else
        ufw_rc=$?
    fi
    if [ "$ufw_rc" -ne 0 ]; then
        add_result "security" "host_firewall" "WARN" \
            "UFW status is not readable by the node user" \
            "$output" \
            "Review sudo ufw status verbose manually; Node Doctor does not request sudo."
        return
    fi

    if printf '%s\n' "$output" | grep -Fqx 'Status: active'; then
        add_result "security" "host_firewall" "PASS" "UFW reports active"
    elif printf '%s\n' "$output" | grep -Fqx 'Status: inactive'; then
        add_result "security" "host_firewall" "WARN" \
            "UFW reports inactive" \
            "Another provider firewall may still be in use" \
            "Verify the server's effective ingress policy before validator operation."
    else
        add_result "security" "host_firewall" "WARN" "UFW returned an unrecognised status" "$output"
        return
    fi

    if [ -n "$RPC_PORT" ]; then
        if printf '%s\n' "$output" | awk -v port="$RPC_PORT" '
            $1 ~ ("^" port "(/tcp)?$") && $2 == "ALLOW" { found=1 }
            END { exit !found }
        '; then
            add_result "security" "firewall_rpc_rule" "WARN" \
                "UFW contains an explicit allow rule for the RPC port" \
                "RPC port=$RPC_PORT" \
                "Remove unnecessary public RPC ingress only after confirming reverse-proxy and access requirements."
        else
            add_result "security" "firewall_rpc_rule" "PASS" "No explicit UFW allow rule exposes the RPC port" "RPC port=$RPC_PORT"
        fi
    fi
}

check_hardware() {
    local cpu_count mem_kib mem_gib disk_target df_line used_percent available_kib available_gib
    local source_device rota_values max_rota

    if command -v nproc >/dev/null 2>&1; then
        cpu_count=$(nproc 2>/dev/null || true)
    else
        cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
    fi
    if [[ "$cpu_count" =~ ^[0-9]+$ ]] && [ "$cpu_count" -ge 4 ]; then
        add_result "hardware" "cpu" "PASS" "CPU count meets the Valley of Gnoland baseline" "vCPU=$cpu_count"
    elif [[ "$cpu_count" =~ ^[0-9]+$ ]] && [ "$cpu_count" -ge 2 ]; then
        add_result "hardware" "cpu" "WARN" "CPU count is below the recommended baseline" "vCPU=$cpu_count; recommended at least 4"
    else
        add_result "hardware" "cpu" "FAIL" "CPU count is critically low or unavailable" "vCPU=${cpu_count:-unknown}"
    fi

    mem_kib=${GNOLAND_DOCTOR_MEM_TOTAL_KIB:-$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)}
    if [[ "$mem_kib" =~ ^[0-9]+$ ]]; then
        mem_gib=$((mem_kib / 1024 / 1024))
