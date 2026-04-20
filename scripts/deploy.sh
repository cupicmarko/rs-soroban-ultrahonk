#!/bin/bash
set -e

echo "1. Ensuring alice account is set up..."
./scripts/fund_account.sh >/dev/null 2>&1 || true

echo "2. Rebuilding circuits..."
# Run the build circuit script to generate the VK, proof, public_inputs
./contracts/rs-soroban-ultrahonk/tests/build_circuits.sh

echo "3. Building the Soroban contract..."
stellar contract build

echo "4. Deploying the contract to localnet..."
CONTRACT_ID=$(stellar contract deploy \
  --wasm target/wasm32v1-none/release/rs_soroban_ultrahonk.wasm \
  --source alice \
  --network local \
  -- \
  --vk_bytes-file-path contracts/rs-soroban-ultrahonk/tests/simple_circuit/target/vk)

echo "$CONTRACT_ID" > .contract_id

echo ""
echo "Contract deployed successfully! Contract ID:"
echo "$CONTRACT_ID (saved to .contract_id)"
