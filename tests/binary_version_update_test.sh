#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSIONS="$ROOT/VERSIONS.json"
INSTALLER="$ROOT/resources/gnoland_node_install_testnet.sh"
UPDATER="$ROOT/resources/gnoland_update.sh"
README="$ROOT/README.md"
NODE_GUIDE="$ROOT/docs/node-guide.md"
USAGE="$ROOT/docs/usage.md"

TAG='v1.7.0-rc.1'
COMMIT='e4c2e7d9fe0f6f7aeeda54885ca1fe5cea991319'
GNOLAND_SHA='df61577df813d18184d9bfc15f8f28854f37c35bae659bac857d5cae388ea9fa'
GNOKEY_SHA='6e0fdeed8829865add8b6c8efef41466ae1f05d0598618b02f67533fe582a643'

fail() { echo "BINARY_VERSION_UPDATE_TEST_FAIL: $*" >&2; exit 1; }

[ "$(jq -r '.network' "$VERSIONS")" = 'Gno.land Onyx' ] || fail 'VERSIONS network is not Onyx'
[ "$(jq -r '.chain_id' "$VERSIONS")" = 'onyx-1' ] || fail 'VERSIONS chain_id is not onyx-1'
[ "$(jq -r '.binary_release_tag' "$VERSIONS")" = "$TAG" ] || fail 'VERSIONS binary tag drifted'
[ "$(jq -r '.binary_release_commit' "$VERSIONS")" = "$COMMIT" ] || fail 'VERSIONS binary commit drifted'
[ "$(jq -r '.verification_status' "$VERSIONS")" = 'static_verified_live_rehearsal_pending' ] || fail 'VERSIONS verification status drifted'
[ "$(jq -r '.binaries.gnoland_linux_amd64' "$VERSIONS")" = "$GNOLAND_SHA" ] || fail 'VERSIONS gnoland checksum drifted'
[ "$(jq -r '.binaries.gnokey_linux_amd64' "$VERSIONS")" = "$GNOKEY_SHA" ] || fail 'VERSIONS gnokey checksum drifted'

for script in "$INSTALLER" "$UPDATER"; do
    rel="${script#$ROOT/}"
    grep -Fq "readonly BINARY_RELEASE_TAG=\"$TAG\"" "$script" || fail "missing binary tag in $rel"
    grep -Fq "readonly BINARY_RELEASE_COMMIT=\"$COMMIT\"" "$script" || fail "missing binary release commit in $rel"
    grep -Fq 'https://github.com/gnolang/gno/releases/download/${BINARY_RELEASE_TAG}/gnoland_linux_amd64' "$script" || fail "gnoland URL is not tag-driven in $rel"
    grep -Fq 'https://github.com/gnolang/gno/releases/download/${BINARY_RELEASE_TAG}/gnokey_linux_amd64' "$script" || fail "gnokey URL is not tag-driven in $rel"
    grep -Fq "$GNOLAND_SHA" "$script" || fail "gnoland checksum missing in $rel"
    grep -Fq "$GNOKEY_SHA" "$script" || fail "gnokey checksum missing in $rel"
    grep -Fq 'verify_binary_release_metadata' "$script" || fail "release metadata verification missing in $rel"
    grep -Fq 'verify_staged_binary_versions' "$script" || fail "staged binary version verification missing in $rel"
done

# The updater must complete metadata, downloads, and both checks before its first
# service stop. This is a source-level ordering guard, not a live-node test.
metadata_call=$(grep -nE '^verify_binary_release_metadata$' "$UPDATER" | tail -n1 | cut -d: -f1)
gnoland_download=$(grep -nF 'curl -fsSL "https://github.com/gnolang/gno/releases/download/${BINARY_RELEASE_TAG}/gnoland_linux_amd64"' "$UPDATER" | cut -d: -f1)
gnokey_download=$(grep -nF 'curl -fsSL "https://github.com/gnolang/gno/releases/download/${BINARY_RELEASE_TAG}/gnokey_linux_amd64"' "$UPDATER" | cut -d: -f1)
gnoland_check=$(grep -nF 'echo "${GNOLAND_SHA256}  $tmpdir/gnoland" | sha256sum -c -' "$UPDATER" | cut -d: -f1)
gnokey_check=$(grep -nF 'echo "${GNOKEY_SHA256}  $tmpdir/gnokey" | sha256sum -c -' "$UPDATER" | cut -d: -f1)
version_check=$(grep -nF 'verify_staged_binary_versions "$tmpdir/gnoland" "$tmpdir/gnokey"' "$UPDATER" | cut -d: -f1)
stop_line=$(grep -nF 'sudo systemctl stop "$GNOLAND_TESTNET_SERVICE_NAME"' "$UPDATER" | cut -d: -f1)
[ -n "$metadata_call" ] && [ -n "$gnoland_download" ] && [ -n "$gnokey_download" ] && [ -n "$gnoland_check" ] && [ -n "$gnokey_check" ] && [ -n "$version_check" ] && [ -n "$stop_line" ] || fail 'updater staging markers missing'
[ "$metadata_call" -lt "$gnoland_download" ] || fail 'release metadata check must precede downloads'
[ "$gnoland_download" -lt "$gnoland_check" ] && [ "$gnokey_download" -lt "$gnokey_check" ] || fail 'downloads must precede checksum checks'
[ "$gnoland_check" -lt "$stop_line" ] && [ "$gnokey_check" -lt "$stop_line" ] || fail 'checksums must precede service stop'
[ "$version_check" -lt "$stop_line" ] || fail 'binary version checks must precede service stop'
grep -Fq 'cleanup_and_recover' "$UPDATER" || fail 'updater recovery handler missing'

grep -Fq "$TAG" "$README" || fail 'README binary tag missing'
grep -Fq "$COMMIT" "$README" "$NODE_GUIDE" "$USAGE" || fail 'binary release commit missing from docs'
grep -Fq "$GNOLAND_SHA" "$NODE_GUIDE" || fail 'gnoland checksum missing from node guide'
grep -Fq "$GNOKEY_SHA" "$NODE_GUIDE" || fail 'gnokey checksum missing from node guide'
grep -Fq 'stages all network artifacts, and only then stops the node' "$USAGE" || fail 'usage guide does not document staged update safety'

echo 'BINARY_VERSION_UPDATE_TEST_OK'
