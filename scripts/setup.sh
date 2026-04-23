#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ultrahonk Verifier: Local Environment Setup ===${NC}"

# Function to check if a command exists
check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed.${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ $1 is installed${NC}"
    return 0
}

# 1. Check core dependencies
echo -e "\n${BLUE}1. Checking dependencies...${NC}"
MISSING=0
check_cmd "stellar" || MISSING=1
check_cmd "docker" || MISSING=1
check_cmd "rustc" || MISSING=1
check_cmd "cargo" || MISSING=1
check_cmd "nargo" || MISSING=1
check_cmd "bb" || MISSING=1
check_cmd "node" || MISSING=1
check_cmd "npm" || MISSING=1

if [ "$MISSING" -eq 1 ]; then
    echo -e "${RED}\nPlease install the missing dependencies before continuing.${NC}"
    exit 1
fi

# 2. Setup Rust target
echo -e "\n${BLUE}2. Adding Soroban Rust target...${NC}"
rustup target add wasm32v1-none
echo -e "${GREEN}✓ Target wasm32v1-none added${NC}"

# 3. Install NPM dependencies for helpers
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "\n${BLUE}3. Installing Node.js dependencies...${NC}"
NPM_CMD="install"
if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    NPM_CMD="ci"
fi

if [ -d "$ROOT_DIR/scripts/measure_ultrahonk_costs" ]; then
    echo "Installing measurement script dependencies (npm $NPM_CMD)..."
    cd "$ROOT_DIR/scripts/measure_ultrahonk_costs"
    npm "$NPM_CMD"
    echo -e "${GREEN}✓ measure_ultrahonk_costs dependencies installed${NC}"
fi

if [ -d "$ROOT_DIR/scripts/invoke_ultrahonk" ]; then
    echo "Installing invocation script dependencies (npm $NPM_CMD)..."
    cd "$ROOT_DIR/scripts/invoke_ultrahonk"
    npm "$NPM_CMD"
    echo -e "${GREEN}✓ invoke_ultrahonk dependencies installed${NC}"
fi

# 4. Final check and guidance
echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
echo -e "You can now start developing using the modular scripts:"
echo -e "  1. ${BLUE}./scripts/start_stellar.sh${NC}  - Start localnet"
echo -e "  2. ${BLUE}./scripts/fund_account.sh${NC}   - Fund 'alice' account"
echo -e "  3. ${BLUE}./scripts/deploy.sh${NC}         - Build and deploy contract"
echo -e "  4. ${BLUE}./scripts/verify.sh${NC}         - Run verification and measurements"
