variable "project" {
  description = "Project ID to deploy into"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  default     = "europe-west1"
  type        = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.64.0.0/16"
}

variable "vault_fqdn" {
  type = string
}

variable "vault_chart_version" {
  type    = string
  default = "0.30.1"
}

variable "vault_repository" {
  type    = string
  default = "hashicorp/vault"
}

variable "vault_version_tag" {
  type    = string
  default = ""
}

variable "vault_license" {
  type    = string
  default = null
}

variable "gke_cluster_name" {
  type    = string
  default = "vault-autopilot"
}

variable "create_k8s" {
  type    = bool
  default = true
}

variable "vault_client_cidrs" {
  type    = list(string)
  default = []
}

variable "dns_managed_zone_name" {
  type = string
}

variable "proxy_subnet_cidr" {
  description = "CIDR range for the proxy-only subnet used by EXTERNAL_MANAGED ALB"
  type        = string
  default     = "10.65.0.0/16"
}
