#!/bin/bash

# Directory for certificates
CERT_DIR="certs"

# Client certificate validity (1 year)
CLIENT_DAYS=365

# Client name (can be overridden via argument)
CLIENT_NAME="${1:-client}"

# Check if CA exists
if [ ! -f "$CERT_DIR/ca.pem" ] || [ ! -f "$CERT_DIR/ca.key" ]; then
    echo "Error: CA certificate not found. Run 50_vault_cert_auth.sh first."
    exit 1
fi

# Check if client cert already exists
if [ -f "$CERT_DIR/$CLIENT_NAME.pem" ] && [ -f "$CERT_DIR/$CLIENT_NAME.key" ]; then
    echo "Client certificate already exists at $CERT_DIR/$CLIENT_NAME.pem"
    echo "To regenerate, remove existing $CLIENT_NAME.pem and $CLIENT_NAME.key first"
    exit 0
fi

echo "Generating client private key..."
openssl ecparam -genkey -name prime256v1 -out "$CERT_DIR/$CLIENT_NAME.key"

echo "Creating Certificate Signing Request..."
openssl req -new \
    -key "$CERT_DIR/$CLIENT_NAME.key" \
    -out "$CERT_DIR/$CLIENT_NAME.csr" \
    -subj "/CN=$CLIENT_NAME/O=ACME"

echo "Signing client certificate with CA..."
openssl x509 -req \
    -in "$CERT_DIR/$CLIENT_NAME.csr" \
    -CA "$CERT_DIR/ca.pem" \
    -CAkey "$CERT_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERT_DIR/$CLIENT_NAME.pem" \
    -days $CLIENT_DAYS \
    -sha256

# Clean up CSR
rm -f "$CERT_DIR/$CLIENT_NAME.csr"

echo
echo "Client certificate generated successfully:"
echo "  Certificate: $CERT_DIR/$CLIENT_NAME.pem"
echo "  Private Key: $CERT_DIR/$CLIENT_NAME.key"
echo
echo "Verify certificate:"
openssl x509 -in "$CERT_DIR/$CLIENT_NAME.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
echo
echo "Verify certificate chain:"
openssl verify -CAfile "$CERT_DIR/ca.pem" "$CERT_DIR/$CLIENT_NAME.pem"
echo
echo "To authenticate with Vault:"
echo "  vault login -method=cert \\"
echo "      client_cert=$CERT_DIR/$CLIENT_NAME.pem \\"
echo "      client_key=$CERT_DIR/$CLIENT_NAME.key \\"
echo "      name=default"
echo
