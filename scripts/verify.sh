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

echo "Invoking verify_proof on contract $CONTRACT_ID..."
stellar contract invoke \
  --id "$CONTRACT_ID" \
  --source alice \
  --network local \
  --send yes \
  --cost \
  -- \
  verify_proof \
  --public_inputs-file-path contracts/rs-soroban-ultrahonk/tests/simple_circuit/target/public_inputs \
  --proof_bytes-file-path contracts/rs-soroban-ultrahonk/tests/simple_circuit/target/proof

echo ""
echo "Proof successfully verified on-chain!"
