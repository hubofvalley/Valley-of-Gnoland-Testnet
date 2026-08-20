#!/bin/bash

set -euo pipefail

TEST_PARTS=(
    "part-00.bash:b4133f56daf3cd70c7bd5c7f6f9dc58ef09921f1b5a83951af6d4c8e1d857530"
    "part-01.bash:e0aa3e71a97e9b8bb76a2b4e67c358ff7a95718a4946cfd5f78b32a7177f7adc"
    "part-02.bash:ed79d745048bfd6fc9cdde3a24451b7ceca1043b1b9b210e5d9b078b81ed943b"
    "part-03.bash:5f8c9d1777a56c27b510031b10f5a857641de6def5b9b98b9982a7dadd70283a"
    "part-04.bash:ffa31d7ac3e56c810eab66210593c2c52479ecd12eb15c083906687e808c7423"
)
EXPECTED_ASSEMBLED_SHA256="ee8e70cd77a170ed62d913d1560abd913206d1dc99cb46674d023c355bb3d590"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PART_DIR="$SCRIPT_DIR/node-doctor"
ASSEMBLED_TEST=""

cleanup_test_loader() {
    if [ -n "$ASSEMBLED_TEST" ] && [ -f "$ASSEMBLED_TEST" ]; then
        rm -f "$ASSEMBLED_TEST"
    fi
}
trap cleanup_test_loader EXIT

test_loader_error() {
    echo "Node Doctor test loader failed: $*" >&2
    exit 2
}

command -v sha256sum >/dev/null 2>&1 || test_loader_error "sha256sum is required."
ASSEMBLED_TEST=$(mktemp "$SCRIPT_DIR/.node_doctor_test_assembled.XXXXXX")
: > "$ASSEMBLED_TEST"

for part_spec in "${TEST_PARTS[@]}"; do
    part_name=${part_spec%%:*}
    expected_sha=${part_spec#*:}
    part_path="$PART_DIR/$part_name"
    [ -f "$part_path" ] || test_loader_error "missing $part_path"
    actual_sha=$(sha256sum -- "$part_path" | awk '{print $1}')
    [ "$actual_sha" = "$expected_sha" ] || test_loader_error "$part_name checksum mismatch"
    cat "$part_path" >> "$ASSEMBLED_TEST"
done

assembled_sha=$(sha256sum -- "$ASSEMBLED_TEST" | awk '{print $1}')
[ "$assembled_sha" = "$EXPECTED_ASSEMBLED_SHA256" ] || test_loader_error "assembled test checksum mismatch"

bash "$ASSEMBLED_TEST"
