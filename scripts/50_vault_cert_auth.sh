#!/bin/bash

# Wait for Vault pods to be ready
kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l "app.kubernetes.io/name=vault" --namespace vault --timeout=5m
sleep 3

# Set Vault token from init output
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')

# Enable the cert auth method
vault auth enable cert

# Configure a certificate role using the CA
# Clients presenting certificates signed by this CA will be authenticated
vault write auth/cert/certs/default \
    display_name="Certificate Authentication" \
    policies="default" \
    certificate=@certs/ca.pem \
    ttl=3600

echo "Cert auth method enabled and configured with CA from certs/ca.pem"
echo
