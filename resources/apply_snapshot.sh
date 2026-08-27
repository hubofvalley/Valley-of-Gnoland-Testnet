#!/bin/bash

set -euo pipefail

cat >&2 <<'MSG'
Pearl snapshot application is intentionally disabled in Valley of Gnoland.

Pearl is a fresh chain. The snapshot providers previously configured by this
repository were Sapphire-specific and MUST NOT be applied to pearl-1.

Use normal P2P sync for now. Re-enable this helper only after a Pearl snapshot
provider, chain ID, archive layout, and verification metadata have been reviewed
and pinned for Pearl.
MSG
exit 2
