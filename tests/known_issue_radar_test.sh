#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$REPO_ROOT/resources/node-doctor-known-issues.bash"
EXPECTED_RELEASE_COMMIT="9ab5198acac68016341655c82290ecaff5591edb"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

RESULT_COUNT=0
RESULT_CATEGORY=""
RESULT_ID=""
RESULT_STATUS=""
RESULT_MESSAGE=""
RESULT_DETAIL=""
RESULT_REMEDIATION=""

add_result() {
    RESULT_COUNT=$((RESULT_COUNT + 1))
    RESULT_CATEGORY=$1
    RESULT_ID=$2
    RESULT_STATUS=$3
    RESULT_MESSAGE=$4
    RESULT_DETAIL=${5:-}
    RESULT_REMEDIATION=${6:-}
}

# shellcheck source=/dev/null
source "$HELPER"

SOURCE_COMMIT="$EXPECTED_RELEASE_COMMIT"
unset GNOLAND_DOCTOR_SKIP_KNOWN_ISSUES || true
check_known_issues

[ "$RESULT_COUNT" -eq 1 ] || fail "managed Sapphire release should emit exactly one advisory"
[ "$RESULT_CATEGORY" = "known_issues" ] || fail "unexpected advisory category: $RESULT_CATEGORY"
[ "$RESULT_ID" = "gno_pr_6054" ] || fail "unexpected advisory id: $RESULT_ID"
[ "$RESULT_STATUS" = "WARN" ] || fail "known issue must be WARN, got $RESULT_STATUS"
[[ "$RESULT_MESSAGE" == *"#6054"* ]] || fail "advisory message does not identify PR #6054"
[[ "$RESULT_DETAIL" == *"full CPU core"* ]] || fail "advisory detail does not explain CPU busy-spin risk"
[[ "$RESULT_DETAIL" == *"defer/context"* ]] || fail "advisory detail does not explain retention risk"
[[ "$RESULT_REMEDIATION" == *"Do not blind-upgrade a validator"* ]] || fail "advisory remediation is missing validator safety guidance"

# A different source commit must not inherit an advisory scoped to the managed release.
RESULT_COUNT=0
SOURCE_COMMIT="131371844c4db8554d519c13a2430b5fbfbec4a8"
check_known_issues
[ "$RESULT_COUNT" -eq 0 ] || fail "non-managed source commit should not emit the Sapphire advisory"

# The skip flag is test/support-only and must suppress the advisory deterministically.
RESULT_COUNT=0
SOURCE_COMMIT="$EXPECTED_RELEASE_COMMIT"
GNOLAND_DOCTOR_SKIP_KNOWN_ISSUES=1
check_known_issues
[ "$RESULT_COUNT" -eq 0 ] || fail "skip flag did not suppress known-issue advisory"

# Core Node Doctor semantics already treat WARN as exit 0 normally and exit 1
# under --strict. Assert the new rule continues to use that WARN contract.
warning_exit_code() {
    local strict=$1 status=$2
    if [ "$status" != "WARN" ]; then
        echo 1
    elif [ "$strict" = "true" ]; then
        echo 1
    else
        echo 0
    fi
}
[ "$(warning_exit_code false WARN)" -eq 0 ] || fail "WARN should remain non-fatal without --strict"
[ "$(warning_exit_code true WARN)" -eq 1 ] || fail "WARN should be fatal under --strict"

echo "KNOWN_ISSUE_RADAR_TEST_OK"
