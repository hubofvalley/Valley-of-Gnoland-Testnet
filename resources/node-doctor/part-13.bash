                    "System clock is not NTP-synchronised" \
                    "NTPSynchronized=no" \
                    "Restore reliable time synchronisation before validator operation."
                ;;
            *)
                add_result "hardware" "time_sync" "WARN" "NTP synchronisation state is unavailable"
                ;;
        esac
    else
        add_result "hardware" "time_sync" "WARN" "timedatectl is unavailable; clock synchronisation was not checked"
    fi
}

check_secret_permissions() {
    local target mode insecure=() checked=0

    for target in "$GNOLAND_HOME/secrets" "$GNOKEY_HOME"; do
        if [ ! -e "$target" ]; then
            add_result "security" "$(basename "$target")_permissions" "WARN" "Sensitive path is not present" "$target"
            continue
        fi
        while IFS= read -r -d '' item; do
            checked=$((checked + 1))
            mode=$(stat -c '%a' "$item" 2>/dev/null || true)
            if [[ "$mode" =~ ^[0-7]{3,4}$ ]]; then
                mode=${mode: -3}
                if [ "${mode:1:1}" != "0" ] || [ "${mode:2:1}" != "0" ]; then
                    insecure+=("$item($mode)")
                fi
            fi
        done < <(find "$target" -xdev -maxdepth 4 -print0 2>/dev/null)
    done

    if [ "$checked" -eq 0 ]; then
        add_result "security" "secret_permissions" "WARN" "No secret or keyring paths were available for permission inspection"
    elif [ "${#insecure[@]}" -eq 0 ]; then
        add_result "security" "secret_permissions" "PASS" "Node secrets and operator keyring are not group/world-accessible" "Entries checked=$checked"
    else
        add_result "security" "secret_permissions" "FAIL" \
            "Sensitive files or directories are accessible by group/other" \
            "${insecure[*]}" \
            "Review ownership first, then restrict directories to 700 and secret files to 600 where appropriate."
    fi
}

check_runtime_and_paths
check_dependencies
check_service
check_source_and_artifacts
check_config
check_live_network
check_firewall
check_hardware
check_secret_permissions

if $JSON_MODE; then
    emit_json
else
    emit_text
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
if $STRICT_MODE && [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
