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

# Backend Service
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

  dynamic "backend" {
    for_each = var.create && !var.use_gateway_api ? [1] : []
    content {
      group           = google_compute_network_endpoint_group.vault[0].id
      balancing_mode  = "RATE"
      max_rate_per_endpoint = 100
    }
  }

  # mTLS configuration
  dynamic "security_settings" {
    for_each = var.mtls_enabled ? [1] : []
    content {
      client_tls_policy = google_network_security_server_tls_policy.mtls[0].id
    }
  }
}

# Network Endpoint Group (Standalone NEG for the Vault service)
resource "google_compute_network_endpoint_group" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name                  = "vault-neg-${var.unique_id}"
  project               = var.project
  zone                  = data.google_compute_zones.available.names[0]
  network               = data.google_compute_network.default.id
  subnetwork            = data.google_compute_subnetwork.default.id
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port          = 8200
}

# URL Map
resource "google_compute_url_map" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name            = "vault-urlmap-${var.unique_id}"
  project         = var.project
  default_service = google_compute_backend_service.vault[0].id
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "vault" {
  count = var.create && !var.use_gateway_api ? 1 : 0

  name            = "vault-https-proxy-${var.unique_id}"
  project         = var.project
  url_map         = google_compute_url_map.vault[0].id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default[0].id}"
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
