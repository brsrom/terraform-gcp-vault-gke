variable "create" {
  type    = bool
  default = true
}

variable "dns_names" {
  type = list(string)
  default = [
    "localhost",
    "*.vault-internal",
    "*.vault-internal.vault.svc.cluster.local",
    "vault.vault.svc",
    "vault.vault.svc.cluster.local"
  ]
}

variable "domain" {
  type    = string
  default = "vault-internal"
}

variable "namespace" {
  type    = string
  default = "vault"
}

variable "tls_secret_name" {
  type    = string
  default = "tls"
}

variable "tls_secret_crt" {
  type    = string
  default = "tls.crt"
}

variable "tls_secret_key" {
  type    = string
  default = "tls.key"
}

variable "tls_ca_secret_name" {
  type    = string
  default = "tls-ca"
}

variable "tls_ca_secret_crt" {
  type    = string
  default = "ca.crt"
}

variable "organization" {
  type    = string
  default = "ACME"
}

variable "unique_id" {
  type = string
}

variable "region" {
  type        = string
  description = "GCP region for resources"
}

variable "project" {
  type        = string
  description = "GCP project ID for resources"
}

variable "vault_backend_config" {
  type    = string
  default = "vault-backend-config"
}

variable "vault_fqdn" {
  type = string
  validation {
    condition     = length(var.vault_fqdn) <= 63
    error_message = "Vault FQDN max length 63 characters."
  }
}

variable "managed_certificate_name" {
  type    = string
  default = "vault-managed-cert"

}

variable "cloud_armour_enabled" {
  type    = bool
  default = true
}

variable "cloud_armour_whitelist_cidrs" {
  type = list(string)
}

variable "vault_chart_version" {
  type = string
}

variable "vault_version_tag" {
  type = string
}

variable "vault_repository" {
  type = string
}

variable "vault_license_secret_name" {
  type    = string
  default = "vault-enterprise"
}

variable "vault_license_secret_key" {
  type    = string
  default = "license"
}

variable "vault_license" {
  type    = string
  default = null
}

variable "vault_log_level" {
  type        = string
  default     = "INFO"
  description = "Log level for Vault (TRACE, DEBUG, INFO, WARN, ERROR)"
}

variable "dns_managed_zone_name" {
  type = string
}

variable "ca_certificate_pem" {
  type        = string
  description = "PEM encoded CA certificate for trust config"
}
