#!/bin/bash

# Directory for certificates
CERT_DIR="certs"
mkdir -p "$CERT_DIR"

# CA certificate validity (10 years)
CA_DAYS=3650

# Generate CA if it doesn't exist
if [ -f "$CERT_DIR/ca.pem" ] && [ -f "$CERT_DIR/ca.key" ]; then
    echo "CA certificate already exists at $CERT_DIR/ca.pem"
else
    echo "Generating CA private key..."
    openssl ecparam -genkey -name prime256v1 -out "$CERT_DIR/ca.key"

    echo "Generating CA certificate..."
    openssl req -x509 -new -nodes \
        -key "$CERT_DIR/ca.key" \
        -sha256 \
        -days $CA_DAYS \
        -out "$CERT_DIR/ca.pem" \
        -subj "/CN=Vault CA/O=ACME"

    echo "CA certificate generated successfully"
    openssl x509 -in "$CERT_DIR/ca.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
fi

echo

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
    certificate=@"$CERT_DIR/ca.pem" \
    ttl=3600

echo "Cert auth method enabled and configured with CA from $CERT_DIR/ca.pem"
echo
