#!/bin/bash
set -e

if [ -z "$1" ]; then
  if [ -f ".contract_id" ]; then
    CONTRACT_ID=$(cat .contract_id)
    echo "Auto-loaded CONTRACT_ID: $CONTRACT_ID"
  else
    echo "Usage: $0 <CONTRACT_ID>"
    echo "Or run scripts/deploy.sh first to generate .contract_id automatically."
    exit 1
  fi
else
  CONTRACT_ID="$1"
fi

PUBLIC_INPUTS="contracts/rs-soroban-ultrahonk/tests/simple_circuit/target/public_inputs"
PROOF="contracts/rs-soroban-ultrahonk/tests/simple_circuit/target/proof"

if [ ! -f "$PUBLIC_INPUTS" ] || [ ! -f "$PROOF" ]; then
  echo "Error: Verification artifacts not found at $PUBLIC_INPUTS or $PROOF"
  exit 1
fi

PI_SIZE=$(stat -c%s "$PUBLIC_INPUTS")
PROOF_SIZE=$(stat -c%s "$PROOF")

echo -e "\x1b[1m\x1b[34m--- Artifact Summary ---\x1b[0m"
echo "Public Inputs : $PI_SIZE bytes"
echo "Proof         : $PROOF_SIZE bytes"
echo "------------------------"

echo "Invoking verify_proof on contract $CONTRACT_ID..."
stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source alice \
  --network local \
  --send yes \
  -- \
  verify_proof \
  --public_inputs-file-path "$PUBLIC_INPUTS" \
  --proof_bytes-file-path "$PROOF"

echo ""
echo -e "\x1b[1m\x1b[32mProof successfully verified on-chain!\x1b[0m"

# Now run the measurement script for a detailed report
echo ""
echo "Generating detailed performance report..."
SOURCE_SECRET=$(stellar keys secret alice | tail -n 1 | tr -d '[:space:]')
pushd scripts/measure_ultrahonk_costs >/dev/null
npm run measure -- \
  --contract-id "$CONTRACT_ID" \
  --source-secret "$SOURCE_SECRET" \
  --dataset ../../contracts/rs-soroban-ultrahonk/tests/simple_circuit/target
popd >/dev/null
