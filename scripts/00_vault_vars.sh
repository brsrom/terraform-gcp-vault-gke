#!/bin/bash

export VAULT_ADDR=$(terraform output -raw vault_url)
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')
