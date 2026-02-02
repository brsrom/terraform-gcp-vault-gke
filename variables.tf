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

variable "mtls_enabled" {
  description = "Enable mTLS for client certificate authentication"
  type        = bool
  default     = false
}

variable "client_ca_pem" {
  description = "PEM-encoded CA certificate for client certificate validation"
  type        = string
  default     = ""
}

variable "use_gateway_api" {
  description = "Use GKE Gateway API for load balancing. Set to false for standalone ALB."
  type        = bool
  default     = true
}
