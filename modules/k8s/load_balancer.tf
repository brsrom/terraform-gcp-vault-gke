# Standalone Application Load Balancer resources
# Used when use_gateway_api = false

# Health Check for Vault
resource "google_compute_health_check" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name    = "vault-health-${var.unique_id}"
  project = var.project

  https_health_check {
    port         = 8200
    request_path = "/v1/sys/health?standbyok=true"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Backend Service for main UI/API (no cert header forwarding)
resource "google_compute_backend_service" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name                  = "vault-backend-${var.unique_id}"
  project               = var.project
  protocol              = "HTTPS"
  port_name             = "https"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.vault[0].id]
  security_policy       = var.cloud_armour_enabled ? google_compute_security_policy.whitelist[0].id : null
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Add NEGs from all zones as backends
  dynamic "backend" {
    for_each = var.create && !var.use_gateway_api ? data.google_compute_network_endpoint_group.vault : {}
    content {
      group                 = backend.value.id
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
    }
  }
}

# Data source for NEGs created by GKE from the Vault service annotation
# GKE creates one NEG per zone where pods are running
data "google_compute_network_endpoint_group" "vault" {
  for_each = var.create && !var.use_gateway_api ? toset(data.google_compute_zones.available.names) : toset([])
  name     = "vault-neg-${var.unique_id}"
  zone     = each.value
  project  = var.project

  depends_on = [helm_release.vault]
}

# URL Map
resource "google_compute_url_map" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name            = "vault-urlmap-${var.unique_id}"
  project         = var.project
  default_service = google_compute_backend_service.vault[0].id
}

# Target HTTPS Proxy for main UI/API (no mTLS)
resource "google_compute_target_https_proxy" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name            = "vault-https-proxy-${var.unique_id}"
  project         = var.project
  url_map         = google_compute_url_map.vault[0].id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default[0].id}"
  # No mTLS policy - this endpoint is for UI/browser access
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name                  = "vault-https-rule-${var.unique_id}"
  project               = var.project
  target                = google_compute_target_https_proxy.vault[0].id
  port_range            = "443"
  ip_address            = google_compute_global_address.default[0].address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Data sources for network
data "google_compute_network" "default" {
  name    = "vpc-${local.common_suffix}"
  project = var.project
}

data "google_compute_subnetwork" "default" {
  name    = "gke-snet-${local.common_suffix}"
  region  = var.region
  project = var.project
}

data "google_compute_zones" "available" {
  project = var.project
  region  = var.region
}

locals {
  common_suffix = var.unique_id
}

# ============================================================================
# mTLS Resources for Cert Auth Endpoint
# ============================================================================

# Health Check for Vault mTLS listener (port 8400)
resource "google_compute_health_check" "vault_mtls" {
  count = var.create && var.mtls_enabled && !var.use_gateway_api ? 1 : 0

  name    = "vault-mtls-health-${var.unique_id}"
  project = var.project

  https_health_check {
    port         = 8400
    request_path = "/v1/sys/health?standbyok=true"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Data source for mTLS NEGs created by GKE from the vault-mtls service
data "google_compute_network_endpoint_group" "vault_mtls" {
  for_each = var.create && var.mtls_enabled && !var.use_gateway_api ? toset(data.google_compute_zones.available.names) : toset([])
  name     = "vault-neg-mtls-${var.unique_id}"
  zone     = each.value
  project  = var.project

  depends_on = [kubernetes_service_v1.vault_mtls]
}

# Backend Service for mTLS cert auth (with cert header forwarding)
resource "google_compute_backend_service" "vault_mtls" {
  count = var.create && var.mtls_enabled && !var.use_gateway_api ? 1 : 0

  name                  = "vault-mtls-backend-${var.unique_id}"
  project               = var.project
  protocol              = "HTTPS"
  port_name             = "https-mtls"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.vault_mtls[0].id]
  security_policy       = var.cloud_armour_enabled ? google_compute_security_policy.whitelist[0].id : null
  load_balancing_scheme = "EXTERNAL_MANAGED"

  # Forward client certificate to backend for mTLS authentication
  # Uses {client_cert_leaf} which is Base64-encoded per RFC 9440
  custom_request_headers = [
    "x-client-cert-leaf: {client_cert_leaf}"
  ]

  # Add mTLS NEGs from all zones as backends
  dynamic "backend" {
    for_each = var.create && var.mtls_enabled && !var.use_gateway_api ? data.google_compute_network_endpoint_group.vault_mtls : {}
    content {
      group                 = backend.value.id
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
    }
  }
}

# URL Map for mTLS endpoint
resource "google_compute_url_map" "vault_mtls" {
  count = var.create && var.mtls_enabled && !var.use_gateway_api ? 1 : 0

  name            = "vault-mtls-urlmap-${var.unique_id}"
  project         = var.project
  default_service = google_compute_backend_service.vault_mtls[0].id
}

# Target HTTPS Proxy for mTLS (with TLS policy)
resource "google_compute_target_https_proxy" "vault_mtls" {
  count = var.create && var.mtls_enabled && !var.use_gateway_api ? 1 : 0

  name            = "vault-mtls-https-proxy-${var.unique_id}"
  project         = var.project
  url_map         = google_compute_url_map.vault_mtls[0].id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default[0].id}"

  # mTLS configuration for client certificate authentication
  server_tls_policy = google_network_security_server_tls_policy.mtls[0].id
}

# Global Forwarding Rule for mTLS endpoint (same IP, routes by SNI/hostname)
resource "google_compute_global_forwarding_rule" "vault_mtls" {
  count = var.create && var.mtls_enabled && !var.use_gateway_api ? 1 : 0

  name                  = "vault-mtls-https-rule-${var.unique_id}"
  project               = var.project
  target                = google_compute_target_https_proxy.vault_mtls[0].id
  port_range            = "8443"
  ip_address            = google_compute_global_address.default[0].address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
