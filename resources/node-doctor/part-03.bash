    esac
}

sha256_file() {
    sha256sum -- "$1" 2>/dev/null | awk '{print $1}'
}

unit_value() {
    local key=$1 file=$2
    sed -n "s/^${key}=//p" "$file" 2>/dev/null | tail -n 1
}

toml_get() {
    local section=$1 key=$2 file=${3:-$CONFIG_FILE}
    awk -v wanted_section="$section" -v wanted_key="$key" '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
            line=$0
            gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", line)
            current_section=line
            next
        }
        {
            line=$0
            if (current_section != wanted_section) next
            if (line !~ "^[[:space:]]*" wanted_key "[[:space:]]*=") next
            sub("^[[:space:]]*" wanted_key "[[:space:]]*=[[:space:]]*", "", line)
            line=trim(line)
            if (line ~ /^".*"[[:space:]]*(#.*)?$/) {
                sub(/^"/, "", line)
                sub(/"[[:space:]]*(#.*)?$/, "", line)
            } else {
                sub(/[[:space:]]+#.*$/, "", line)
                line=trim(line)
            }
            print line
            exit
        }
    ' "$file" 2>/dev/null
}

address_host() {
    local address=${1#tcp://}
    if [[ "$address" =~ ^\[([^]]+)\]:([0-9]+)$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    elif [[ "$address" =~ ^([^:]+):([0-9]+)$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

address_port() {
    local address=${1#tcp://}
    if [[ "$address" =~ ^\[([^]]+)\]:([0-9]+)$ ]]; then
        printf '%s' "${BASH_REMATCH[2]}"
    elif [[ "$address" =~ ^([^:]+):([0-9]+)$ ]]; then
        printf '%s' "${BASH_REMATCH[2]}"
    fi
}

is_loopback_host() {
    case "$1" in
        127.0.0.1|localhost|::1) return 0 ;;
        *) return 1 ;;
    esac
}

config_drift_check() {
    local section=$1 key=$2 expected=$3 severity=$4 check_id=$5 observed command_key
    observed=$(toml_get "$section" "$key")
    command_key=$key
    if [ -n "$section" ]; then
        command_key="${section}.${key}"
    fi

    if [ -z "$observed" ]; then
        add_result "config" "$check_id" "$severity" \
            "Required value is missing" \
            "${command_key}=<missing>; expected ${expected}" \
            "Run: gnoland config set -config-path '$CONFIG_FILE' '$command_key' '$expected', then review and restart the node."
    elif [ "$observed" = "$expected" ]; then
        add_result "config" "$check_id" "PASS" \
            "Configuration matches Sapphire" \
            "${command_key}=${observed}"
    else
        add_result "config" "$check_id" "$severity" \
            "Configuration drift detected" \
            "${command_key}=${observed}; expected ${expected}" \
            "Run: gnoland config set -config-path '$CONFIG_FILE' '$command_key' '$expected', then review and restart the node."
    fi
}

check_runtime_and_paths() {
    local unsafe_paths=() path

    if [ "${#INVALID_THRESHOLD_OVERRIDES[@]}" -eq 0 ]; then
        add_result "runtime" "threshold_overrides" "PASS" "Doctor threshold overrides are valid"
    else
        add_result "runtime" "threshold_overrides" "WARN" \
            "Invalid doctor threshold overrides were ignored" \
            "${INVALID_THRESHOLD_OVERRIDES[*]}" \
            "Use non-negative integers and keep FAIL thresholds stricter than WARN thresholds."
    fi

    if [ -n "${SUDO_USER:-}" ]; then
        add_result "runtime" "sudo_context" "FAIL" \
            "Doctor is running through sudo" \
            "SUDO_USER=$SUDO_USER; HOME=$HOME" \
            "Run the doctor as the Gnoland OS user. It does not require sudo."
    else
        add_result "runtime" "sudo_context" "PASS" "Running as the node OS user" "OS user: $OS_USER"
    fi
