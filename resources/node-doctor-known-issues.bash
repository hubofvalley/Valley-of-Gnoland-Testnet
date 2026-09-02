# shellcheck shell=bash

check_known_issues() {
    if [ "${GNOLAND_DOCTOR_SKIP_KNOWN_ISSUES:-0}" = "1" ]; then
        return 0
    fi

    if [ "${SOURCE_COMMIT:-}" != "$EXPECTED_RELEASE_COMMIT" ]; then
        return 0
    fi

    add_result "known_issues" "gno_pr_6054" "WARN" \
        "Managed Pearl release predates upstream P2P dial-loop fix #6054" \
        "Persistent peers in backoff can busy-spin near one full CPU core; repeated dials can retain defer/context objects until restart. Upstream fix merged 2026-08-13 (131371844c4db8554d519c13a2430b5fbfbec4a8)." \
        "Do not blind-upgrade a validator. Review the next official Pearl release or a validated backport before changing the running binary."
}
