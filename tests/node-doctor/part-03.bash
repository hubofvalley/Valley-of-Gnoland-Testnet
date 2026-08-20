# Introduce chain-critical drift and public RPC exposure.
sed -i 's/prune_strategy = "syncable"/prune_strategy = "nothing"/' "$FIXTURE_HOME/gno/gnoland-data/config/config.toml"
sed -i 's/timeout_commit = "3s"/timeout_commit = "5s"/' "$FIXTURE_HOME/gno/gnoland-data/config/config.toml"
sed -i 's/peer_gossip_sleep_duration = "10ms"/peer_gossip_sleep_duration = "20ms"/' "$FIXTURE_HOME/gno/gnoland-data/config/config.toml"
sed -i 's/flush_throttle_timeout = "10ms"/flush_throttle_timeout = "20ms"/' "$FIXTURE_HOME/gno/gnoland-data/config/config.toml"
sed -i 's/pex = true/pex = false/' "$FIXTURE_HOME/gno/gnoland-data/config/config.toml"
sed -i 's#tcp://127.0.0.1:26657#tcp://0.0.0.0:26657#' "$FIXTURE_HOME/gno/gnoland-data/config/config.toml"
sed -i 's#persistent_peers = ".*"#persistent_peers = ""#' "$FIXTURE_HOME/gno/gnoland-data/config/config.toml"

set +e
"${common_env[@]}" bash "$DOCTOR" --json > "$TEST_ROOT/drift.json"
drift_rc=$?
set -e
[ "$drift_rc" -eq 1 ] || fail "drift run should return 1, got $drift_rc"
assert_jq "$TEST_ROOT/drift.json" '.summary.fail >= 6'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "prune_strategy" and .status == "FAIL")'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "timeout_commit" and .status == "FAIL")'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "peer_gossip_sleep_duration" and .status == "FAIL")'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "flush_throttle_timeout" and .status == "FAIL")'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "peer_exchange" and .status == "WARN")'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "rpc_bind" and .status == "FAIL")'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "persistent_peers" and .status == "FAIL")'
assert_jq "$TEST_ROOT/drift.json" '.checks[] | select(.id == "timeout_commit" and (.remediation | length > 0))'


# A wrong RPC chain ID is chain-critical.
write_healthy_config
set +e
"${common_env[@]}" MOCK_LOCAL_NETWORK=wrong-chain bash "$DOCTOR" --json > "$TEST_ROOT/wrong-chain.json"
wrong_chain_rc=$?
set -e
[ "$wrong_chain_rc" -eq 1 ] || fail "wrong chain run should return 1, got $wrong_chain_rc"
assert_jq "$TEST_ROOT/wrong-chain.json" '.checks[] | select(.id == "chain_id" and .status == "FAIL")'

# An untrusted public comparison endpoint must not be used for block-lag decisions.
write_healthy_config
set +e
"${common_env[@]}" MOCK_PUBLIC_NETWORK=wrong-chain bash "$DOCTOR" --json > "$TEST_ROOT/wrong-public-chain.json"
wrong_public_rc=$?
set -e
[ "$wrong_public_rc" -eq 1 ] || fail "wrong public chain run should return 1, got $wrong_public_rc"
assert_jq "$TEST_ROOT/wrong-public-chain.json" '.checks[] | select(.id == "public_rpc_chain_id" and .status == "FAIL")'
assert_jq "$TEST_ROOT/wrong-public-chain.json" '.checks[] | select(.id == "block_lag" and .status == "WARN")'

# An explicit UFW RPC allow rule is a warning, even when config still binds RPC to loopback.
"${common_env[@]}" MOCK_UFW_ALLOW_RPC=1 bash "$DOCTOR" --json > "$TEST_ROOT/ufw-rpc-rule.json"
assert_jq "$TEST_ROOT/ufw-rpc-rule.json" '.summary.fail == 0'
assert_jq "$TEST_ROOT/ufw-rpc-rule.json" '.checks[] | select(.id == "firewall_rpc_rule" and .status == "WARN")'

# Service ownership drift must be treated as a failure.
cp "$SERVICE_DIR/gnoland.service" "$SERVICE_DIR/gnoland.service.bak"
sed -i 's/^User=.*/User=another-user/' "$SERVICE_DIR/gnoland.service"
set +e
"${common_env[@]}" bash "$DOCTOR" --json > "$TEST_ROOT/ownership-drift.json"
ownership_rc=$?
set -e
