    if [[ "$GNOLAND_SERVICE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9_.@-]*$ ]]; then
        add_result "runtime" "service_name" "PASS" "Service name is valid" "$GNOLAND_SERVICE_NAME.service"
    else
        add_result "runtime" "service_name" "FAIL" \
            "Service name is invalid" \
            "$GNOLAND_SERVICE_NAME" \
            "Use a service name beginning with a letter or number and containing only _, ., @, or -."
    fi

    for path in "$GNO_SOURCE_DIR" "$GNOLAND_HOME" "$GNOKEY_HOME" "$GNOROOT" "$GNOLAND_BIN" "$GNOKEY_BIN" "$GNOLAND_GENESIS"; do
        if ! path_is_under_home "$path"; then
            unsafe_paths+=("$path")
        fi
    done
    if [ "${#unsafe_paths[@]}" -eq 0 ]; then
        add_result "runtime" "instance_paths" "PASS" "Instance paths remain under the current user's home" "$HOME"
    else
        add_result "runtime" "instance_paths" "FAIL" \
            "One or more instance paths are outside the current user's home" \
            "${unsafe_paths[*]}" \
            "Review exported GNOLAND/GNO paths before operating this instance."
    fi
}

check_dependencies() {
    local required=(awk sed grep curl jq sha256sum systemctl df stat realpath date find)
    local optional=(git ss timedatectl findmnt lsblk nproc)
    local missing_required=() missing_optional=() command_name

    for command_name in "${required[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 || missing_required+=("$command_name")
    done
    for command_name in "${optional[@]}"; do
        command -v "$command_name" >/dev/null 2>&1 || missing_optional+=("$command_name")
    done

    if [ "${#missing_required[@]}" -gt 0 ]; then
        add_result "runtime" "required_commands" "FAIL" \
            "Required inspection commands are missing" \
            "${missing_required[*]}" \
            "Install the missing packages before relying on the doctor result."
    else
        add_result "runtime" "required_commands" "PASS" "Required inspection commands are available"
    fi

    if [ "${#missing_optional[@]}" -gt 0 ]; then
        add_result "runtime" "optional_commands" "WARN" \
            "Some extended checks will be unavailable" \
            "${missing_optional[*]}" \
            "Install the matching Ubuntu packages to enable every check."
    else
        add_result "runtime" "optional_commands" "PASS" "Extended inspection commands are available"
    fi
}

SERVICE_FILE=""
check_service() {
    local service_state unit_user unit_workdir unit_exec restart_policy nofile_limit

    if ! command -v systemctl >/dev/null 2>&1; then
        add_result "service" "unit_file" "FAIL" "systemctl is unavailable"
        return
    fi

    SERVICE_FILE=$(systemctl show "$GNOLAND_SERVICE_NAME" -p FragmentPath --value 2>/dev/null || true)
    if [ -z "$SERVICE_FILE" ]; then
        add_result "service" "unit_file" "FAIL" \
            "Systemd service is not installed" \
            "$GNOLAND_SERVICE_NAME.service" \
            "Deploy the node or export the correct GNOLAND_SERVICE_NAME."
        return
    fi
    if [ ! -f "$SERVICE_FILE" ]; then
        add_result "service" "unit_file" "FAIL" \
            "Systemd returned an unreadable unit path" \
            "$SERVICE_FILE" \
            "Inspect: systemctl cat '$GNOLAND_SERVICE_NAME'."
        return
    fi
    add_result "service" "unit_file" "PASS" "Systemd unit file is present" "$SERVICE_FILE"

    unit_user=$(unit_value "User" "$SERVICE_FILE")
    unit_workdir=$(unit_value "WorkingDirectory" "$SERVICE_FILE")
    if [ "$unit_user" = "$OS_USER" ] && [ "$unit_workdir" = "$GNO_SOURCE_DIR" ]; then
        add_result "service" "ownership" "PASS" "Service belongs to this instance" "User=$unit_user; WorkingDirectory=$unit_workdir"
    else
