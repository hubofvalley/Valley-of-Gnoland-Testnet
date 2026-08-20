[ "$ownership_rc" -eq 1 ] || fail "ownership drift run should return 1, got $ownership_rc"
assert_jq "$TEST_ROOT/ownership-drift.json" '.checks[] | select(.id == "ownership" and .status == "FAIL")'
mv "$SERVICE_DIR/gnoland.service.bak" "$SERVICE_DIR/gnoland.service"

# Restore health, then force a warning to verify strict-mode semantics.
write_healthy_config
set +e
"${common_env[@]}" GNOLAND_DOCTOR_WARN_FREE_DISK_GIB=999999 bash "$DOCTOR" --json --strict > "$TEST_ROOT/strict.json"
strict_rc=$?
set -e
[ "$strict_rc" -eq 1 ] || fail "strict warning run should return 1, got $strict_rc"
assert_jq "$TEST_ROOT/strict.json" '.summary.fail == 0'
assert_jq "$TEST_ROOT/strict.json" '.summary.warn >= 1'
assert_jq "$TEST_ROOT/strict.json" '.summary.exit_code == 1'

# Offline mode must remain valid JSON and report the skipped comparison.
"${common_env[@]}" bash "$DOCTOR" --json --offline > "$TEST_ROOT/offline.json"
assert_jq "$TEST_ROOT/offline.json" '.offline == true'
assert_jq "$TEST_ROOT/offline.json" '.checks[] | select(.id == "public_rpc" and .status == "WARN")'



VERSIONS_FILE="$REPO_ROOT/VERSIONS.json"
if [ -f "$VERSIONS_FILE" ]; then
    DOCTOR_SOURCES=("$DOCTOR" "$DOCTOR_PART_DIR"/*.bash)
    grep -Fq "EXPECTED_CHAIN_ID=\"$(jq -r '.chain_id' "$VERSIONS_FILE")\"" "${DOCTOR_SOURCES[@]}" || fail "doctor chain ID differs from VERSIONS.json"
    grep -Fq "EXPECTED_RELEASE_COMMIT=\"$(jq -r '.release_commit' "$VERSIONS_FILE")\"" "${DOCTOR_SOURCES[@]}" || fail "doctor release commit differs from VERSIONS.json"
    grep -Fq "EXPECTED_GENESIS_SHA256=\"$(jq -r '.genesis_sha256' "$VERSIONS_FILE")\"" "${DOCTOR_SOURCES[@]}" || fail "doctor genesis checksum differs from VERSIONS.json"
    grep -Fq "EXPECTED_GNOLAND_SHA256=\"$(jq -r '.binaries.gnoland_linux_amd64' "$VERSIONS_FILE")\"" "${DOCTOR_SOURCES[@]}" || fail "doctor gnoland checksum differs from VERSIONS.json"
    grep -Fq "EXPECTED_GNOKEY_SHA256=\"$(jq -r '.binaries.gnokey_linux_amd64' "$VERSIONS_FILE")\"" "${DOCTOR_SOURCES[@]}" || fail "doctor gnokey checksum differs from VERSIONS.json"
    grep -Fq "EXPECTED_PERSISTENT_PEERS=\"$(jq -r '.endpoints.official_persistent_peers' "$VERSIONS_FILE")\"" "${DOCTOR_SOURCES[@]}" || fail "doctor peer baseline differs from VERSIONS.json"
fi

MAIN_SCRIPT="$REPO_ROOT/resources/valleyofGnoland.sh"
if [ -f "$MAIN_SCRIPT" ]; then
    grep -q '"doctor"' "$MAIN_SCRIPT" || fail "main script is missing doctor command mode"
    grep -q '"node-doctor"' "$MAIN_SCRIPT" || fail "main script is missing node-doctor alias"
    grep -q '1g. Run Node Doctor' "$MAIN_SCRIPT" || fail "main menu is missing Node Doctor"
    grep -q 'run_node_doctor_script' "$MAIN_SCRIPT" || fail "main script is missing Node Doctor runner"

    command_line=$(grep -n 'Non-interactive command mode' "$MAIN_SCRIPT" | head -n 1 | cut -d: -f1)
    profile_line=$(grep -n 'source "$HOME/.bash_profile"' "$MAIN_SCRIPT" | head -n 1 | cut -d: -f1)
    [ -n "$command_line" ] && [ -n "$profile_line" ] && [ "$command_line" -lt "$profile_line" ] || \
        fail "doctor command mode must run before .bash_profile is sourced"

    "${common_env[@]}" bash "$MAIN_SCRIPT" doctor --json > "$TEST_ROOT/main-dispatch.json"
    assert_jq "$TEST_ROOT/main-dispatch.json" '.read_only == true and .summary.fail == 0'
    [ ! -e "$FIXTURE_HOME/profile-side-effect" ] || fail "main doctor dispatch executed arbitrary .bash_profile commands"
fi

echo "NODE_DOCTOR_TEST_OK"
