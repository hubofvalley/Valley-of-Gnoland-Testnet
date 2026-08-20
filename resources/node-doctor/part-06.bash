            add_result "artifacts" "source_commit" "FAIL" \
                "Gno source commit drift detected" \
                "Observed ${SOURCE_COMMIT:-unavailable}; expected $EXPECTED_RELEASE_COMMIT" \
                "Do not update a validator blindly. Review the source and use the verified updater."
        fi

        source_remote=$(git -C "$GNO_SOURCE_DIR" remote get-url origin 2>/dev/null || true)
        if [ "$source_remote" = "$EXPECTED_SOURCE_REMOTE" ]; then
            add_result "artifacts" "source_remote" "PASS" "Gno source remote is official" "$source_remote"
        else
            add_result "artifacts" "source_remote" "WARN" \
                "Gno source remote differs from the managed value" \
                "Observed ${source_remote:-unavailable}; expected $EXPECTED_SOURCE_REMOTE" \
                "Verify the remote manually before fetching or updating."
        fi
    else
        add_result "artifacts" "source_commit" "WARN" "git is unavailable; source pinning could not be verified"
    fi

    if [ -x "$GNOLAND_BIN" ]; then
        actual_sha=$(sha256_file "$GNOLAND_BIN")
        if [ "$actual_sha" = "$EXPECTED_GNOLAND_SHA256" ]; then
            add_result "artifacts" "gnoland_binary" "PASS" "gnoland matches the official prebuilt checksum" "SHA256=$actual_sha"
        elif [ "$SOURCE_COMMIT" = "$EXPECTED_RELEASE_COMMIT" ]; then
            add_result "artifacts" "gnoland_binary" "WARN" \
                "gnoland does not match the official prebuilt checksum" \
                "SHA256=${actual_sha:-unavailable}; pinned source is present, so this may be a local source build" \
                "Confirm that this binary was built from the pinned Sapphire source before validator use."
        else
            add_result "artifacts" "gnoland_binary" "FAIL" \
                "gnoland checksum is untrusted and source pinning is not verified" \
                "SHA256=${actual_sha:-unavailable}" \
                "Replace it only through the verified update flow after testing on a non-validator node."
        fi
    else
        add_result "artifacts" "gnoland_binary" "FAIL" "gnoland binary is missing or not executable" "$GNOLAND_BIN"
    fi

    if [ -x "$GNOKEY_BIN" ]; then
        actual_sha=$(sha256_file "$GNOKEY_BIN")
        if [ "$actual_sha" = "$EXPECTED_GNOKEY_SHA256" ]; then
            add_result "artifacts" "gnokey_binary" "PASS" "gnokey matches the official prebuilt checksum" "SHA256=$actual_sha"
        elif [ "$SOURCE_COMMIT" = "$EXPECTED_RELEASE_COMMIT" ]; then
            add_result "artifacts" "gnokey_binary" "WARN" \
                "gnokey does not match the official prebuilt checksum" \
                "SHA256=${actual_sha:-unavailable}; this may be a local source build" \
                "Confirm the binary provenance before signing transactions."
        else
            add_result "artifacts" "gnokey_binary" "FAIL" \
                "gnokey checksum is untrusted and source pinning is not verified" \
                "SHA256=${actual_sha:-unavailable}"
        fi
    else
        add_result "artifacts" "gnokey_binary" "FAIL" "gnokey binary is missing or not executable" "$GNOKEY_BIN"
    fi

    if [ -f "$GNOLAND_GENESIS" ]; then
        actual_sha=$(sha256_file "$GNOLAND_GENESIS")
        if [ "$actual_sha" = "$EXPECTED_GENESIS_SHA256" ]; then
            add_result "artifacts" "genesis" "PASS" "Genesis checksum matches Sapphire" "SHA256=$actual_sha"
        else
            add_result "artifacts" "genesis" "FAIL" \
                "Genesis checksum mismatch" \
                "Observed ${actual_sha:-unavailable}; expected $EXPECTED_GENESIS_SHA256" \
                "Stop before restarting. Restore the official Sapphire genesis through the verified installer."
        fi
    else
