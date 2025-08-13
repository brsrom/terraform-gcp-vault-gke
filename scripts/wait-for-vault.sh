#!/bin/bash

# Wait for VAULT_ADDR to return HTTP 200

# if VAULT_ADDR is not set exit
if [ -z "$VAULT_ADDR" ]; then
  echo "VAULT_ADDR is not set. Please set it to the Vault server address."
  exit 1
fi

echo "Waiting for Vault at $VAULT_ADDR to be available..."

until curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" | grep -q "200"; do
  echo "waiting..."
  sleep 10
done

echo "Vault is available at $VAULT_ADDR"
