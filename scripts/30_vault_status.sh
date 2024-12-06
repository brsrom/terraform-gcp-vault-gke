#!/bin/bash
#set -x

export VAULT_ADDR=$(terraform output -raw vault_url)
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')

kubectl get all -n vault
kubectl get ingress -n vault
echo
sleep 3
kubectl exec -n vault -ti vault-0 -- vault status
kubectl exec -n vault -ti vault-1 -- vault status
kubectl exec -n vault -ti vault-2 -- vault status
echo
kubectl exec -n vault -ti vault-0 -- sh -c "wget -qO- --no-check-certificate https://127.0.0.1:8200/v1/sys/health?perfstandbyok=true\&perfstandbyok=true"
echo
curl -skv "$VAULT_ADDR/v1/sys/health?standbyok=true&perfstandbyok=true" | jq
echo
kubectl exec -n vault -ti vault-0 -- sh -c "VAULT_TOKEN=$VAULT_TOKEN vault operator raft list-peers"
echo
echo "export VAULT_ADDR: $VAULT_ADDR"
echo "export VAULT_TOKEN: $VAULT_TOKEN"
