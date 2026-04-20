#!/bin/bash
set -e

ACCOUNT="alice"

echo "Checking/Generating identity for '$ACCOUNT'..."
stellar keys generate "$ACCOUNT" 2>/dev/null || true

echo "Funding '$ACCOUNT' on local network..."
stellar keys fund "$ACCOUNT" --network local 2>/dev/null || true

echo "Address for '$ACCOUNT':"
stellar keys address "$ACCOUNT"
