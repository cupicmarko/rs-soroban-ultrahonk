#!/bin/bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

echo -e "${BLUE}Checking/Generating identity for '$STELLAR_SOURCE_ACCOUNT'...${NC}"
stellar keys generate "$STELLAR_SOURCE_ACCOUNT" 2>/dev/null || true

echo -e "${BLUE}Funding '$STELLAR_SOURCE_ACCOUNT' on network '$STELLAR_NETWORK_NAME'...${NC}"
stellar keys fund "$STELLAR_SOURCE_ACCOUNT" --network "$STELLAR_NETWORK_NAME" 2>/dev/null || true

echo -e "${GREEN}Address for '$STELLAR_SOURCE_ACCOUNT':${NC}"
stellar keys address "$STELLAR_SOURCE_ACCOUNT"
