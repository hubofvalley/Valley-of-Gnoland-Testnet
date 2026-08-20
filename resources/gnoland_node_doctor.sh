#!/bin/bash

set -u -o pipefail

NODE_DOCTOR_PARTS=(
    "part-00.bash:b3f4d2dce9ec6b60f6ebd8b604f4934357cee15803ff3461be694037e2e4f852"
    "part-01.bash:4cef87d8f71f94abf04d4e71a0fb52154ab5593392d0d7a7da8d35a94f129850"
    "part-02.bash:53d42d1f181f8f178281b6f092cf3268328d0ce7901f74416aa4b76114900f54"
    "part-03.bash:dba67fe7963bf7a4c0726edba502a0b9d2fbdf2607240cb7ce5c5d8b3cc97525"
    "part-04.bash:576f70d9c9c2c80ddad0336143d2b0c0f1852390bd95abdfff703b5791e8e5d8"
    "part-05.bash:822d4ba20ed5cbe2d323ecb0c19c2e22479ce7cde512d5692b37f73ddd3dbd8a"
    "part-06.bash:ef726f737827e11c7faa10a55a0ab4df3c9bdeb660f05975e1734c6b77c7646b"
    "part-07.bash:af2feef031c146d84e72655ffbd930f16490ea2cf30f6a0df91751027d0967c1"
    "part-08.bash:7241e86a3c5d8932507acc0ce1025ca03ad6dd746c5ea6d021ed0d20594dac62"
    "part-09.bash:a234e9c77e2fe5cb7ac1421077ce0e20c93ab30b7a8d80774add4c72fdfe5ed0"
    "part-10.bash:4a1a62a60dc7c5cac946e4b30dbc09a8e6877d15ea06af31ffe6d2dc58ef2cc7"
    "part-11.bash:5a0d52e645b8a308ad5e8d62ccb338cc653138c1d2fde97996d62551dde7c53e"
    "part-12.bash:9a62aacdeb5b43808366c22f9d21f04a8a5783b08ee962249a6891fcc7160c12"
    "part-13.bash:ec0347833ef60cddadf43dfeb7fb5a514eecf4a64fe1598501b6540dccd94aee"
)
EXPECTED_ASSEMBLED_SHA256="9888721450926cb1af5485ae49589dd20c201aa6f538c99832505b554e83ece9"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)
LOCAL_PART_DIR="$SCRIPT_DIR/node-doctor"
NODE_DOCTOR_REF=${GNOLAND_NODE_DOCTOR_REF:-main}
REMOTE_PART_BASE=${GNOLAND_NODE_DOCTOR_RAW_BASE:-https://raw.githubusercontent.com/hubofvalley/Valley-of-Gnoland-Testnet/$NODE_DOCTOR_REF/resources/node-doctor}
TEMP_DIR=$(mktemp -d)
ASSEMBLED_SCRIPT="$TEMP_DIR/gnoland_node_doctor_assembled.sh"

cleanup_node_doctor_loader() {
    rm -rf "$TEMP_DIR"
}
trap cleanup_node_doctor_loader EXIT

node_doctor_loader_error() {
    echo "Node Doctor loader failed: $*" >&2
    exit 2
}

if ! command -v sha256sum >/dev/null 2>&1; then
    node_doctor_loader_error "sha256sum is required to verify Node Doctor parts."
fi

: > "$ASSEMBLED_SCRIPT"
for part_spec in "${NODE_DOCTOR_PARTS[@]}"; do
    part_name=${part_spec%:*}
    expected_sha=${part_spec#*:}
    part_path="$LOCAL_PART_DIR/$part_name"

    if [ ! -f "$part_path" ]; then
        if ! command -v curl >/dev/null 2>&1; then
            node_doctor_loader_error "curl is required to download missing part $part_name."
        fi
        part_path="$TEMP_DIR/$part_name"
        if ! curl -fsSL "$REMOTE_PART_BASE/$part_name" -o "$part_path"; then
            node_doctor_loader_error "could not download $part_name from $REMOTE_PART_BASE."
        fi
    fi

    actual_sha=$(sha256sum -- "$part_path" | awk '{print $1}')
    if [ "$actual_sha" != "$expected_sha" ]; then
        node_doctor_loader_error "$part_name checksum mismatch (observed $actual_sha, expected $expected_sha)."
    fi
    cat "$part_path" >> "$ASSEMBLED_SCRIPT"
done

assembled_sha=$(sha256sum -- "$ASSEMBLED_SCRIPT" | awk '{print $1}')
if [ "$assembled_sha" != "$EXPECTED_ASSEMBLED_SHA256" ]; then
    node_doctor_loader_error "assembled script checksum mismatch (observed $assembled_sha)."
fi

# shellcheck source=/dev/null
source "$ASSEMBLED_SCRIPT"
