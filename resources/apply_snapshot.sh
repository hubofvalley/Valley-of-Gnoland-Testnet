#!/bin/bash

set -euo pipefail

YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Sapphire snapshot is temporarily unavailable.${NC}"
echo "Topaz snapshot archives are incompatible with sapphire-1 and are intentionally blocked."
echo "Use normal peer synchronisation, then check progress with menu option 1e."
