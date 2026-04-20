#!/bin/bash
set -e

echo "Stopping Stellar localnet container..."
stellar container stop local || true

echo "Stellar localnet container stopped."
