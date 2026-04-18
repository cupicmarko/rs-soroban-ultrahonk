#!/usr/bin/env bash
set -euo pipefail

# Configuration
NETWORK="${STELLAR_NETWORK:-local}"
SOURCE="${STELLAR_SOURCE:-alice}"
WASM="target/wasm32v1-none/release/rs_soroban_ultrahonk.wasm"
VK_PATH="tests/simple_circuit/target/vk"

# Ensure we are in the repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "► Ensuring WASM target is installed..."
rustup target add wasm32v1-none >/dev/null 2>&1 || true

echo "► Building Noir circuits..."
bash tests/build_circuits.sh

echo "► Building Soroban contracts (workspace)..."
stellar contract build

echo "► Deploying contract to network: $NETWORK using source: $SOURCE..."
DEPLOY_OUTPUT=$(stellar contract deploy \
  --wasm "$WASM" \
  --source "$SOURCE" \
  --network "$NETWORK" \
  -- \
  --vk_bytes-file-path "$VK_PATH")

echo "✅ Deployment successful!"
echo "------------------------------------------------"
echo "$DEPLOY_OUTPUT" | grep -v "Signing transaction" | grep -v "Sending transaction" | grep -v "Uploading contract" | grep -v "Simulating transaction"
echo "------------------------------------------------"
CONTRACT_ID=$(echo "$DEPLOY_OUTPUT" | tail -n 1 | tr -d '[:space:]')
echo "New Contract ID: $CONTRACT_ID"
echo "$CONTRACT_ID" > .last_contract_id
