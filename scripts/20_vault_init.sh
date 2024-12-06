#!/bin/bash

kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace vault --timeout=5m
sleep 30
echo "Initializing Vault ..."
kubectl exec -n vault -ti vault-0 -- vault operator init -format=json | tee vault-init.json
sleep 10
for i in {0..2}; do
  echo "Unsealing vault-$i ..."
  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
#  kubectl exec -n vault -ti vault-$i -- vault status
  sleep 30
done