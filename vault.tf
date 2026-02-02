module "k8s" {
  source = "./modules/k8s"

  create                       = var.create_k8s
  cloud_armour_whitelist_cidrs = concat([local.management_ip], var.vault_client_cidrs)
  vault_fqdn                   = var.vault_fqdn
  vault_mtls_fqdn              = var.vault_mtls_fqdn
  unique_id                    = module.common.unique_id
  vault_chart_version          = var.vault_chart_version
  vault_license                = var.vault_license
  vault_repository             = var.vault_repository
  vault_version_tag            = var.vault_version_tag
  project                      = var.project
  region                       = var.region
  # vault_log_level              = "DEBUG"
  dns_managed_zone_name = var.dns_managed_zone_name
  mtls_enabled          = var.mtls_enabled
  client_ca_pem         = local.client_ca_pem
  use_gateway_api       = var.use_gateway_api

  depends_on = [
    google_container_cluster.autopilot
  ]
}
