#!/bin/bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

echo -e "${BLUE}Starting Stellar localnet container ($STELLAR_CONTAINER_NAME)...${NC}"
stellar container start -t future --name "$STELLAR_CONTAINER_NAME" --limits unlimited "$@"

echo -e "${BLUE}Configuring network profile ($STELLAR_NETWORK_NAME)...${NC}"
stellar network add "$STELLAR_NETWORK_NAME" \
  --rpc-url "$STELLAR_RPC_URL" \
  --network-passphrase "$STELLAR_NETWORK_PASSPHRASE" || true
stellar network use "$STELLAR_NETWORK_NAME"

echo -e "${BLUE}Waiting for local network to become healthy ($STELLAR_HEALTH_RETRIES attempts)...${NC}"
for i in $(seq 1 "$STELLAR_HEALTH_RETRIES"); do
  OUT=$(stellar network health 2>&1 || true)
  if [[ "$OUT" == *"Unhealthy"* ]]; then
    sleep "$STELLAR_HEALTH_RETRY_INTERVAL"
    continue
  fi
  break
done

echo "Final network health check..."
stellar network health --output json

echo ""
echo "Stellar localnet is running and ready!"
