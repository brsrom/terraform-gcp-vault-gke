#!/bin/bash

kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l "app.kubernetes.io/name=vault" --namespace vault --timeout=5m
sleep 3
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
vault audit enable -path="audit_stdout" file file_path=stdout
vault write sys/config/auditing/request-headers/x-client-cert-leaf hmac=false
vault write sys/config/auditing/request-headers/x-client-cert-present hmac=false
vault write sys/config/auditing/request-headers/x-forwarded-client-cert hmac=false
echo
