    CHECK_IDS+=("$check_id")
    STATUSES+=("$status")
    MESSAGES+=("$message")
    DETAILS+=("$detail")
    REMEDIATIONS+=("$remediation")

    case "$status" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        *)
            STATUSES[${#STATUSES[@]}-1]="FAIL"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            ;;
    esac
}

json_escape() {
    local value=${1-}
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

emit_text() {
    local i status
    printf 'Valley of Gnoland Node Doctor v%s\n' "$DOCTOR_VERSION"
    printf 'Service: %s.service\n' "$GNOLAND_SERVICE_NAME"
    printf 'Node home: %s\n' "$GNOLAND_HOME"
    printf 'Expected network: %s\n\n' "$EXPECTED_CHAIN_ID"

    for i in "${!CHECK_IDS[@]}"; do
        status=${STATUSES[$i]}
        printf '%-9s %s\n' "[$status]" "${CATEGORIES[$i]}/${CHECK_IDS[$i]}: ${MESSAGES[$i]}"
        if [ -n "${DETAILS[$i]}" ]; then
            printf '          Detail: %s\n' "${DETAILS[$i]}"
        fi
        if [ -n "${REMEDIATIONS[$i]}" ]; then
            printf '          Remediation: %s\n' "${REMEDIATIONS[$i]}"
        fi
    done

    printf '\nSummary: PASS=%d WARN=%d FAIL=%d\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
    if [ "$FAIL_COUNT" -gt 0 ]; then
        printf 'Overall: FAIL\n'
    elif [ "$WARN_COUNT" -gt 0 ]; then
        printf 'Overall: WARN\n'
    else
        printf 'Overall: PASS\n'
    fi
    printf 'Read-only inspection complete. No configuration was changed.\n'
}

emit_json() {
    local i comma overall exit_code
    if [ "$FAIL_COUNT" -gt 0 ]; then
        overall="FAIL"
        exit_code=1
    elif [ "$WARN_COUNT" -gt 0 ]; then
        overall="WARN"
        if $STRICT_MODE; then exit_code=1; else exit_code=0; fi
    else
        overall="PASS"
        exit_code=0
    fi

    printf '{'
    printf '"schema_version":"1.0",'
    printf '"doctor_version":"%s",' "$(json_escape "$DOCTOR_VERSION")"
    printf '"generated_at":"%s",' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '"read_only":true,'
    printf '"offline":%s,' "$OFFLINE_MODE"
    printf '"instance":{'
    printf '"service":"%s.service",' "$(json_escape "$GNOLAND_SERVICE_NAME")"
    printf '"os_user":"%s",' "$(json_escape "$OS_USER")"
    printf '"source_dir":"%s",' "$(json_escape "$GNO_SOURCE_DIR")"
    printf '"node_home":"%s",' "$(json_escape "$GNOLAND_HOME")"
    printf '"config_file":"%s",' "$(json_escape "$CONFIG_FILE")"
    printf '"expected_chain_id":"%s"' "$(json_escape "$EXPECTED_CHAIN_ID")"
    printf '},'
    printf '"checks":['
    comma=""
    for i in "${!CHECK_IDS[@]}"; do
        printf '%s{' "$comma"
        printf '"category":"%s",' "$(json_escape "${CATEGORIES[$i]}")"
        printf '"id":"%s",' "$(json_escape "${CHECK_IDS[$i]}")"
        printf '"status":"%s",' "$(json_escape "${STATUSES[$i]}")"
        printf '"message":"%s",' "$(json_escape "${MESSAGES[$i]}")"
        printf '"detail":"%s",' "$(json_escape "${DETAILS[$i]}")"
        printf '"remediation":"%s"' "$(json_escape "${REMEDIATIONS[$i]}")"
        printf '}'
        comma=","
    done
    printf '],'
    printf '"summary":{"pass":%d,"warn":%d,"fail":%d,"overall":"%s","exit_code":%d}' \
        "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$overall" "$exit_code"
    printf '}\n'
}

canonical_path() {
    realpath -m -- "$1" 2>/dev/null || printf '%s' "$1"
}

path_is_under_home() {
    local canonical_home canonical_value
    canonical_home=$(canonical_path "$HOME")
    canonical_value=$(canonical_path "$1")
    case "$canonical_value" in
        "$canonical_home"/*) return 0 ;;
        *) return 1 ;;
