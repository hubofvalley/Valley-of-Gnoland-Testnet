before_hash=$(find "$FIXTURE_HOME" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')
"${common_env[@]}" bash "$DOCTOR" --json > "$TEST_ROOT/healthy.json"
after_hash=$(find "$FIXTURE_HOME" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')
[ "$before_hash" = "$after_hash" ] || fail "doctor changed fixture files"
[ ! -e "$FIXTURE_HOME/profile-side-effect" ] || fail "doctor executed arbitrary .bash_profile commands"
[ ! -e "$FIXTURE_HOME/gnoland-version-command-was-executed" ] || fail "doctor executed the inspected gnoland binary"

jq -e . "$TEST_ROOT/healthy.json" >/dev/null
assert_jq "$TEST_ROOT/healthy.json" '.summary.fail == 0'
assert_jq "$TEST_ROOT/healthy.json" '.summary.overall == "PASS"'
assert_jq "$TEST_ROOT/healthy.json" '.read_only == true'
assert_jq "$TEST_ROOT/healthy.json" '.instance.service == "gnoland.service"'
assert_jq "$TEST_ROOT/healthy.json" '.checks[] | select(.id == "timeout_commit" and .status == "PASS")'
assert_jq "$TEST_ROOT/healthy.json" '.checks[] | select(.id == "rpc_bind" and .status == "PASS")'
assert_jq "$TEST_ROOT/healthy.json" '.checks[] | select(.id == "public_rpc_chain_id" and .status == "PASS")'
assert_jq "$TEST_ROOT/healthy.json" '.checks[] | select(.id == "host_firewall" and .status == "PASS")'
assert_jq "$TEST_ROOT/healthy.json" '.checks[] | select(.id == "firewall_rpc_rule" and .status == "PASS")'

"${common_env[@]}" bash "$DOCTOR" > "$TEST_ROOT/healthy.log"
grep -q '^Valley of Gnoland Node Doctor v1.0.0$' "$TEST_ROOT/healthy.log" || fail "text report header missing"
grep -q '^Summary: PASS=' "$TEST_ROOT/healthy.log" || fail "text report summary missing"
grep -q '^Overall: PASS$' "$TEST_ROOT/healthy.log" || fail "text report overall status missing"
[ "$(bash "$DOCTOR" --version)" = "1.0.0" ] || fail "version output mismatch"
bash "$DOCTOR" --help | grep -q -- '--json' || fail "help output is incomplete"
set +e
bash "$DOCTOR" --not-a-real-option >/dev/null 2>&1
invalid_rc=$?
set -e
[ "$invalid_rc" -eq 2 ] || fail "invalid option should return 2, got $invalid_rc"

# Explicit environment variables take precedence over matching profile exports.
"${common_env[@]}" GNOLAND_SERVICE_NAME=explicit-instance bash "$DOCTOR" --json > "$TEST_ROOT/explicit-env.json"
assert_jq "$TEST_ROOT/explicit-env.json" '.instance.service == "explicit-instance.service"'

# JSON escaping must preserve a literal backslash instead of turning it into an escape sequence.
ESCAPE_HOME="$TEST_ROOT/escape-home"
mkdir -p "$ESCAPE_HOME"
cat > "$ESCAPE_HOME/.bash_profile" <<'EOF_ESCAPE_PROFILE'
export GNOLAND_SERVICE_NAME='bad\name'
EOF_ESCAPE_PROFILE
set +e
env -u SUDO_USER \
    HOME="$ESCAPE_HOME" \
    PATH="/usr/bin:/bin" \
    GNOLAND_DOCTOR_MEM_TOTAL_KIB=33554432 \
    bash "$DOCTOR" --json --offline > "$TEST_ROOT/json-escape.json"
escape_rc=$?
set -e
[ "$escape_rc" -eq 1 ] || fail "incomplete escape fixture should return 1, got $escape_rc"
assert_jq "$TEST_ROOT/json-escape.json" '.instance.service == "bad\\name.service"'

# Invalid or inverted threshold overrides must not corrupt JSON or arithmetic checks.
"${common_env[@]}" \
    GNOLAND_DOCTOR_WARN_BLOCK_LAG=not-a-number \
    GNOLAND_DOCTOR_FAIL_DISK_PERCENT=10 \
    bash "$DOCTOR" --json > "$TEST_ROOT/invalid-thresholds.json"
assert_jq "$TEST_ROOT/invalid-thresholds.json" '.summary.fail == 0'
assert_jq "$TEST_ROOT/invalid-thresholds.json" '.summary.warn >= 1'
assert_jq "$TEST_ROOT/invalid-thresholds.json" '.checks[] | select(.id == "threshold_overrides" and .status == "WARN")'

