#!/bin/bash
set -e

echo "Starting Stellar localnet container..."
stellar container start -t future --name local "$@"

echo "Configuring new local network..."
stellar network add local \
  --rpc-url http://localhost:8000/soroban/rpc \
  --network-passphrase "Standalone Network ; February 2017" || true
stellar network use local

echo "Waiting for local network to become healthy..."
for i in {1..60}; do
  OUT=$(stellar network health 2>&1 || true)
  if [[ "$OUT" == *"Unhealthy"* ]]; then
    sleep 1
    continue
  fi
  break
done

echo "Final network health check..."
stellar network health --output json

echo ""
echo "Stellar localnet is running and ready!"
