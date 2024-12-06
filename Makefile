.PHONY: init gke vault plan output destroy fmt clean

init: fmt
	@terraform init

fmt:
	@terraform fmt -recursive

gke: init
	@terraform validate
	@terraform apply -auto-approve -var create_k8s=false

vault: init
	@terraform apply -auto-approve
	@./scripts/10_gke.sh

plan: init
	@terraform validate
	@terraform plan

output:
	@terraform output

destroy: init vault-uninstall
	@terraform destroy -auto-approve -var create_k8s=false -target google_container_cluster.autopilot
	@terraform destroy -auto-approve -var create_k8s=false

vault-init:
	@./scripts/20_vault_init.sh
	@./scripts/30_vault_status.sh

vault-reinstall: vault-uninstall vault

vault-purge:
	-@helm uninstall vault -n vault
	-@kubectl delete pvc -n vault --all

vault-uninstall:
	@terraform destroy -auto-approve -var create_k8s=false -target module.k8s.helm_release.vault[0]
	@terraform destroy -auto-approve -var create_k8s=false -target module.k8s

vault-events:
	@kubectl get events -n vault -w

vault-logs:
	@kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace vault --timeout=5m
	@kubectl logs -n vault -l app.kubernetes.io/name=vault -f

vault-curl:
	@while true;do curl -sv $(shell terraform output -raw vault_url)/v1/sys/health; sleep 5; done

vault-status:
	@./scripts/30_vault_status.sh

helm-setup:
	@helm repo add hashicorp https://helm.releases.hashicorp.com
	@helm search repo hashicorp/vault

clean:
	-@rm -f terraform.tfstate*
	-@rm -f .terraform.lock.hcl
	-@rm -rf .terraform
	-@rm -rf vault-init.json
