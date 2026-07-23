#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Topaz snapshot support is not available yet.${NC}"
echo -e "${RED}The previous UTSA snapshot is for Test13 and must never be applied to a Topaz node.${NC}"
echo "No service, database, or file was changed."
exit 0
