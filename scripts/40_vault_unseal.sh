#!/bin/bash
kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace vault --timeout=5m

sleep 3

for i in {0..2}; do
  echo "Unsealing vault-$i ..."
  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
  kubectl exec -n vault -ti vault-$i -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
  kubectl exec -n vault -ti vault-$i -- vault status
  sleep 3
done
echo
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
kubectl exec -n vault -ti vault-0 -- sh -c "VAULT_TOKEN=$VAULT_TOKEN vault operator raft list-peers"
echo
