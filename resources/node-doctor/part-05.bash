        add_result "service" "ownership" "FAIL" \
            "Service ownership does not match this instance" \
            "Unit User=${unit_user:-missing}, WorkingDirectory=${unit_workdir:-missing}; expected User=$OS_USER, WorkingDirectory=$GNO_SOURCE_DIR" \
            "Do not restart or modify this service until the selected instance variables are corrected."
    fi

    unit_exec=$(unit_value "ExecStart" "$SERVICE_FILE")
    if [[ "$unit_exec" == "$GNOLAND_BIN start "* ]] &&
       [[ "$unit_exec" == *"--chainid $EXPECTED_CHAIN_ID"* ]] &&
       [[ "$unit_exec" == *"--genesis genesis.json"* ]] &&
       [[ "$unit_exec" == *"--skip-genesis-sig-verification"* ]] &&
       [[ "$unit_exec" == *"--log-level info"* ]]; then
        add_result "service" "exec_start" "PASS" "ExecStart contains the Sapphire safety flags" "$unit_exec"
    else
        add_result "service" "exec_start" "FAIL" \
            "ExecStart drift detected" \
            "${unit_exec:-missing}" \
            "Restore the Valley of Gnoland service command and review it before daemon-reload or restart."
    fi

    if grep -Fxq "Environment=GNOROOT=$GNOROOT" "$SERVICE_FILE"; then
        add_result "service" "gnoroot_environment" "PASS" "Systemd GNOROOT matches this instance" "GNOROOT=$GNOROOT"
    else
        add_result "service" "gnoroot_environment" "FAIL" \
            "Systemd GNOROOT is missing or points elsewhere" \
            "Expected Environment=GNOROOT=$GNOROOT" \
            "Restore the instance-specific GNOROOT only after confirming the service belongs to this node."
    fi

    restart_policy=$(unit_value "Restart" "$SERVICE_FILE")
    if [ "$restart_policy" = "on-failure" ]; then
        add_result "service" "restart_policy" "PASS" "Restart policy matches the managed service" "Restart=$restart_policy"
    else
        add_result "service" "restart_policy" "WARN" \
            "Restart policy differs from the managed service" \
            "Restart=${restart_policy:-missing}; expected on-failure"
    fi

    nofile_limit=$(unit_value "LimitNOFILE" "$SERVICE_FILE")
    if [[ "$nofile_limit" =~ ^[0-9]+$ ]] && [ "$nofile_limit" -ge 65536 ]; then
        add_result "service" "nofile_limit" "PASS" "Open-file limit is sufficient" "LimitNOFILE=$nofile_limit"
    else
        add_result "service" "nofile_limit" "WARN" \
            "Open-file limit is below the Valley of Gnoland baseline" \
            "LimitNOFILE=${nofile_limit:-missing}; expected at least 65536"
    fi

    service_state=$(systemctl is-active "$GNOLAND_SERVICE_NAME" 2>/dev/null || true)
    if [ "$service_state" = "active" ]; then
        add_result "service" "active_state" "PASS" "Gnoland service is active" "$GNOLAND_SERVICE_NAME.service"
    else
        add_result "service" "active_state" "FAIL" \
            "Gnoland service is not active" \
            "State=${service_state:-unknown}" \
            "Inspect: systemctl status '$GNOLAND_SERVICE_NAME' --no-pager -l and journalctl -u '$GNOLAND_SERVICE_NAME' -n 100."
    fi
}

SOURCE_COMMIT=""
check_source_and_artifacts() {
    local source_remote actual_sha resolved

    if [ ! -d "$GNO_SOURCE_DIR/.git" ]; then
        add_result "artifacts" "source_repository" "FAIL" \
            "Pinned Gno source repository is missing" \
            "$GNO_SOURCE_DIR/.git" \
            "Run the verified installer or updater after backing up validator material."
    elif command -v git >/dev/null 2>&1; then
        SOURCE_COMMIT=$(git -C "$GNO_SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)
        if [ "$SOURCE_COMMIT" = "$EXPECTED_RELEASE_COMMIT" ]; then
            add_result "artifacts" "source_commit" "PASS" "Gno source is pinned to the Sapphire release" "$SOURCE_COMMIT"
        else
