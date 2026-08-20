while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --strict) STRICT_MODE=true ;;
        --offline) OFFLINE_MODE=true ;;
        --version)
            echo "$DOCTOR_VERSION"
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

# Import only the simple exported variables written by Valley of Gnoland.
# Never source the profile: arbitrary profile commands would violate the
# doctor's read-only guarantee. Explicit environment variables take precedence.
load_managed_profile_exports() {
    local profile_path=${GNOLAND_DOCTOR_PROFILE:-$HOME/.bash_profile}
    local line name value managed_name
    local -A explicit_environment=()

    [ -r "$profile_path" ] || return 0

    for managed_name in GNO_SOURCE_DIR GNOLAND_HOME GNOLAND_GENESIS GNOKEY_HOME GNOROOT \
        GNOLAND_BIN GNOKEY_BIN GNOLAND_SERVICE_NAME GNOLAND_PORT GNOLAND_REMOTE GNOLAND_PUBLIC_REMOTE; do
        if [[ -v "$managed_name" ]]; then
            explicit_environment["$managed_name"]=1
        fi
    done

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ ! "$line" =~ ^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            continue
        fi
        name=${BASH_REMATCH[1]}
        value=${BASH_REMATCH[2]}

        case "$name" in
            GNO_SOURCE_DIR|GNOLAND_HOME|GNOLAND_GENESIS|GNOKEY_HOME|GNOROOT|GNOLAND_BIN|GNOKEY_BIN|GNOLAND_SERVICE_NAME|GNOLAND_PORT|GNOLAND_REMOTE|GNOLAND_PUBLIC_REMOTE|PATH)
                ;;
            *)
                continue
                ;;
        esac

        # Caller-provided instance variables override the profile. Values read
        # from earlier profile lines do not: the last managed export wins, matching
        # normal shell assignment semantics. PATH remains profile-managed so the
        # usual ~/go/bin prefix is available to command-resolution checks.
        if [ "$name" != "PATH" ] && [ "${explicit_environment[$name]:-0}" = "1" ]; then
            continue
        fi

        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        if [ "${#value}" -ge 2 ]; then
            case "$value" in
                \"*\"|\'*\') value=${value:1:${#value}-2} ;;
            esac
        fi

        value=${value//"\${HOME}"/"$HOME"}
        value=${value//"\$HOME"/"$HOME"}
        value=${value//"\${PATH}"/"$PATH"}
        value=${value//"\$PATH"/"$PATH"}

        printf -v "$name" '%s' "$value"
        export "$name"
    done < "$profile_path"
}

load_managed_profile_exports

OS_USER=$(id -un)
GNO_SOURCE_DIR=${GNO_SOURCE_DIR:-$HOME/gno}
GNOLAND_HOME=${GNOLAND_HOME:-$GNO_SOURCE_DIR/gnoland-data}
if [ "$GNOLAND_HOME" = "$HOME/.gnoland" ] || [ "$GNOLAND_HOME" = "$HOME/gnoland-data" ]; then
    GNOLAND_HOME="$GNO_SOURCE_DIR/gnoland-data"
fi
GNOKEY_HOME=${GNOKEY_HOME:-$HOME/.config/gno}
GNOROOT=${GNOROOT:-$GNO_SOURCE_DIR}
GNOLAND_GENESIS=${GNOLAND_GENESIS:-$GNO_SOURCE_DIR/genesis.json}
GNOLAND_BIN=${GNOLAND_BIN:-$HOME/go/bin/gnoland}
GNOKEY_BIN=${GNOKEY_BIN:-$HOME/go/bin/gnokey}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME:-gnoland}
GNOLAND_SERVICE_NAME=${GNOLAND_SERVICE_NAME%.service}
GNOLAND_PUBLIC_REMOTE=${GNOLAND_PUBLIC_REMOTE:-https://rpc.sapphire.testnets.gno.land}
CONFIG_FILE="$GNOLAND_HOME/config/config.toml"

CATEGORIES=()
CHECK_IDS=()
STATUSES=()
MESSAGES=()
DETAILS=()
REMEDIATIONS=()
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

add_result() {
    local category=$1
    local check_id=$2
    local status=$3
    local message=$4
    local detail=${5:-}
    local remediation=${6:-}

    CATEGORIES+=("$category")
