#!/usr/bin/env bash
set -euo pipefail

# Configuration
CONTRACT_ID="${1:-$(cat .last_contract_id 2>/dev/null || true)}"
NETWORK="${STELLAR_NETWORK:-local}"
SOURCE="${STELLAR_SOURCE:-alice}"
DATASET_DIR="tests/simple_circuit/target"

if [[ -z "$CONTRACT_ID" ]]; then
  echo "❌ Error: No contract ID provided and .last_contract_id not found."
  echo "Usage: ./scripts/verify.sh [CONTRACT_ID]"
  exit 1
fi

echo "► Invoking verify_proof for contract: $CONTRACT_ID"
echo "  Network: $NETWORK"
echo "  Source:  $SOURCE"

# Navigate to repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Ensure dependencies are installed
if [[ ! -d "scripts/invoke_ultrahonk/node_modules" ]]; then
  echo "► Installing npm dependencies..."
  cd scripts/invoke_ultrahonk && npm install && cd ../..
fi

npx ts-node scripts/invoke_ultrahonk/invoke_ultrahonk.ts invoke \
  --dataset "$DATASET_DIR" \
  --contract-id "$CONTRACT_ID" \
  --network "$NETWORK" \
  --source "$SOURCE" \
  --send yes \
  --cost

echo "✅ Verification complete!"
