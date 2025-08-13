#!/bin/bash

if [ -f "vault-init.json" ]; then
    echo "vault-init.json already exists. This means Vault has already been initialized."
    read -p "Do you want to continue and reinitialize Vault? This will overwrite existing keys (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Initialization cancelled."
        exit 1
    fi
fi

echo "Waiting for Vault pods to be in Running state ..."
kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l "app.kubernetes.io/name=vault" --namespace vault --timeout=5m
sleep 30
echo "Initializing Vault ..."
kubectl exec -n vault -ti vault-0 -- vault operator init -format=json | tee vault-init.json
sleep 10
for i in {0..2}; do
#  echo "Unsealing vault-$i ..."
#  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
#  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
#  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
  kubectl exec -n vault -ti vault-$i -- vault status
#  sleep 30
done
