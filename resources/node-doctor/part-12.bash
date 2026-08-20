        if [ "$mem_kib" -ge "$MIN_RAM_PASS_KIB" ]; then
            add_result "hardware" "memory" "PASS" "RAM meets the current Gno operator minimum" "RAM=${mem_gib} GiB"
        elif [ "$mem_kib" -ge "$MIN_RAM_WARN_KIB" ]; then
            add_result "hardware" "memory" "WARN" \
                "RAM is below the current 16 GiB operator minimum" \
                "RAM=${mem_gib} GiB" \
                "Increase RAM before a fresh genesis replay or validator production use."
        else
            add_result "hardware" "memory" "FAIL" \
                "RAM is critically below the current 16 GiB operator minimum" \
                "RAM=${mem_gib} GiB; even the previous 8 GiB guidance is not met"
        fi
    else
        add_result "hardware" "memory" "WARN" "Total RAM could not be determined"
    fi

    if [ -e "$GNOLAND_HOME" ]; then
        disk_target=$GNOLAND_HOME
    elif [ -e "$GNO_SOURCE_DIR" ]; then
        disk_target=$GNO_SOURCE_DIR
    else
        disk_target=$HOME
    fi
    df_line=$(df -Pk "$disk_target" 2>/dev/null | awk 'NR==2 {print $4 " " $5}')
    available_kib=$(printf '%s' "$df_line" | awk '{print $1}')
    used_percent=$(printf '%s' "$df_line" | awk '{gsub(/%/, "", $2); print $2}')
    if [[ "$available_kib" =~ ^[0-9]+$ ]] && [[ "$used_percent" =~ ^[0-9]+$ ]]; then
        available_gib=$((available_kib / 1024 / 1024))
        if [ "$used_percent" -ge "$FAIL_DISK_PERCENT" ] || [ "$available_gib" -le "$FAIL_FREE_DISK_GIB" ]; then
            add_result "hardware" "disk_capacity" "FAIL" "Node filesystem is critically constrained" "Used=${used_percent}%; free=${available_gib} GiB; target=$disk_target"
        elif [ "$used_percent" -ge "$WARN_DISK_PERCENT" ] || [ "$available_gib" -le "$WARN_FREE_DISK_GIB" ]; then
            add_result "hardware" "disk_capacity" "WARN" "Node filesystem is approaching its safety threshold" "Used=${used_percent}%; free=${available_gib} GiB; target=$disk_target"
        else
            add_result "hardware" "disk_capacity" "PASS" "Node filesystem has adequate free space" "Used=${used_percent}%; free=${available_gib} GiB; target=$disk_target"
        fi
    else
        add_result "hardware" "disk_capacity" "WARN" "Disk capacity could not be determined" "$disk_target"
    fi

    if command -v findmnt >/dev/null 2>&1 && command -v lsblk >/dev/null 2>&1; then
        source_device=$(findmnt -no SOURCE --target "$disk_target" 2>/dev/null | head -n 1 || true)
        rota_values=$(lsblk -ndo ROTA "$source_device" 2>/dev/null | awk 'NF {print $1}' || true)
        max_rota=$(printf '%s\n' "$rota_values" | sort -nr | head -n 1)
        if [ "$max_rota" = "0" ]; then
            add_result "hardware" "disk_media" "PASS" "Node filesystem is backed by non-rotational storage" "Source=${source_device:-unknown}"
        elif [ "$max_rota" = "1" ]; then
            add_result "hardware" "disk_media" "WARN" \
                "Node filesystem appears to use rotational storage" \
                "Source=${source_device:-unknown}" \
                "Gno operator guidance recommends local NVMe because consensus is latency-sensitive."
        else
            add_result "hardware" "disk_media" "WARN" "Disk media type could not be resolved" "Source=${source_device:-unknown}"
        fi
    else
        add_result "hardware" "disk_media" "WARN" "findmnt or lsblk is unavailable; disk media type was not checked"
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        case "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)" in
            yes)
                add_result "hardware" "time_sync" "PASS" "System clock reports NTP synchronisation"
                ;;
            no)
                add_result "hardware" "time_sync" "FAIL" \
