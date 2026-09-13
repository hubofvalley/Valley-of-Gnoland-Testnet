#!/bin/bash

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$REPO_ROOT/resources/node-doctor-known-issues.bash"
EXPECTED_RELEASE_COMMIT="c4c72fdd288c757e8da0d93aae867fa479b1b15c"

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
RESULT_IDS=""
RESULT_MESSAGES=""
RESULT_DETAILS=""
RESULT_REMEDIATIONS=""

add_result() {
    RESULT_COUNT=$((RESULT_COUNT + 1))
    RESULT_CATEGORY=$1
    RESULT_ID=$2
    RESULT_STATUS=$3
    RESULT_MESSAGE=$4
    RESULT_DETAIL=${5:-}
    RESULT_REMEDIATION=${6:-}
    RESULT_IDS+="${RESULT_IDS:+ }$RESULT_ID"
    RESULT_MESSAGES+=$'\n'"$RESULT_MESSAGE"
    RESULT_DETAILS+=$'\n'"$RESULT_DETAIL"
    RESULT_REMEDIATIONS+=$'\n'"$RESULT_REMEDIATION"
}

# shellcheck source=/dev/null
source "$HELPER"

# SOURCE_COMMIT and GNOLAND_DOCTOR_SKIP_KNOWN_ISSUES are consumed by the
# sourced helper. ShellCheck cannot infer that data flow across a dynamic source.
# shellcheck disable=SC2034
SOURCE_COMMIT="$EXPECTED_RELEASE_COMMIT"
unset GNOLAND_DOCTOR_SKIP_KNOWN_ISSUES || true
check_known_issues

[ "$RESULT_COUNT" -eq 2 ] || fail "managed Pearl release should emit exactly two advisories"
[ "$RESULT_CATEGORY" = "known_issues" ] || fail "unexpected advisory category: $RESULT_CATEGORY"
[ "$RESULT_STATUS" = "WARN" ] || fail "known issues must remain WARN, got $RESULT_STATUS"
[[ " $RESULT_IDS " == *" gno_pr_6054 "* ]] || fail "missing P2P advisory id"
[[ " $RESULT_IDS " == *" gno_pr_5826 "* ]] || fail "missing type-check DoS advisory id"
[[ "$RESULT_MESSAGES" == *"#6054"* ]] || fail "advisory messages do not identify PR #6054"
[[ "$RESULT_MESSAGES" == *"#5826"* ]] || fail "advisory messages do not identify PR #5826"
[[ "$RESULT_DETAILS" == *"full CPU core"* ]] || fail "P2P advisory does not explain CPU busy-spin risk"
[[ "$RESULT_DETAILS" == *"defer/context"* ]] || fail "P2P advisory does not explain retention risk"
[[ "$RESULT_DETAILS" == *"60-second client timeout"* ]] || fail "type-check advisory does not explain observed wedge duration"
[[ "$RESULT_DETAILS" == *"no transaction gas meter"* ]] || fail "type-check advisory does not explain the missing guard"
[[ "$RESULT_REMEDIATIONS" == *"Do not blind-upgrade a validator"* ]] || fail "P2P advisory is missing validator safety guidance"
[[ "$RESULT_REMEDIATIONS" == *"isolated non-signing nodes"* ]] || fail "type-check advisory is missing RPC isolation guidance"
[[ "$RESULT_REMEDIATIONS" == *"consensus-sensitive backport"* ]] || fail "type-check advisory is missing backport caution"

# A different source commit must not inherit advisories scoped to the managed release.
RESULT_COUNT=0
# shellcheck disable=SC2034
SOURCE_COMMIT="131371844c4db8554d519c13a2430b5fbfbec4a8"
check_known_issues
[ "$RESULT_COUNT" -eq 0 ] || fail "non-managed source commit should not emit Pearl advisories"

# The skip flag is test/support-only and must suppress advisories deterministically.
RESULT_COUNT=0
# shellcheck disable=SC2034
SOURCE_COMMIT="$EXPECTED_RELEASE_COMMIT"
# shellcheck disable=SC2034
GNOLAND_DOCTOR_SKIP_KNOWN_ISSUES=1
check_known_issues
[ "$RESULT_COUNT" -eq 0 ] || fail "skip flag did not suppress known-issue advisories"

# The helper must remain advisory-only. Core Node Doctor owns the normal/strict
# exit-code policy for WARN findings; this test intentionally does not duplicate it.
[ "$RESULT_STATUS" = "WARN" ] || fail "known-issue helper changed from advisory severity"

echo "KNOWN_ISSUE_RADAR_TEST_OK"
