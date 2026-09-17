#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MAIN="$ROOT/resources/valleyofGnoland.sh"
fail() { echo "VALIDATOR_INTERACTIONS_TEST_FAIL: $*" >&2; exit 1; }

for text in \
    '2b. Validator Identity & Status' \
    '2d. Account & Balance Dashboard' \
    '2e. Manage Valoper Profile' \
    '2f. Advanced Validator Operations' \
    '2g. Advanced Query / Realm Inspector' \
    'bank/balances/$operator_addr' \
    'auth/accounts/$operator_addr' \
    'query auth/gasprice' \
    'GetValoperRegisterFee()' \
    'GetValoperRotationFee()' \
    'GetValoperRotationPeriodBlocks()' \
    'UpdateMoniker' \
    'UpdateDescription' \
    'UpdateServerType' \
    'UpdateKeepRunning' \
    'UpdateSigningKey' \
    'vm/qrender' \
    'vm/qfuncs' \
    'vm/qdoc' \
    'vm/qeval' \
    'vm/qstorage' \
    'vm/qpaths?limit=100'; do
    grep -Fq "$text" "$MAIN" || fail "missing operator-console contract: $text"
done

if grep -Fq 'Registration blocked: local node must be synced on' "$MAIN"; then
    fail "registration sync hard-block must not return"
fi
grep -Fq 'operator address does not match key' "$MAIN" || fail "signer/address guard missing"
grep -Fq 'broadcast_valoper_call "$key_name" UpdateSigningKey ROTATE' "$MAIN" || fail "rotation confirmation guard missing"
printf '%s\n' 'VALIDATOR_INTERACTIONS_TEST_OK'
