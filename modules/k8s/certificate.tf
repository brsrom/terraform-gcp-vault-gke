data "google_dns_managed_zone" "default" {
  project = var.project
  name    = var.dns_managed_zone_name
}

resource "google_certificate_manager_dns_authorization" "default" {
  count    = var.create ? 1 : 0
  name     = "vault-cert-dnsauth-${var.unique_id}"
  location = "global"
  domain   = var.vault_fqdn
  type     = "FIXED_RECORD"
}

resource "google_certificate_manager_certificate" "default" {
  count    = var.create ? 1 : 0
  name     = "${var.managed_certificate_name}-${var.unique_id}"
  location = "global"

  managed {
    domains = [var.vault_fqdn]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.default[0].id
    ]
  }
}

resource "google_certificate_manager_certificate_map" "default" {
  count = var.create ? 1 : 0
  name  = "vault-cert-map-${var.unique_id}"
}

resource "google_certificate_manager_certificate_map_entry" "default" {
  count        = var.create ? 1 : 0
  name         = "vault-cert-map-entry-${var.unique_id}"
  certificates = [google_certificate_manager_certificate.default[0].id]
  hostname     = var.vault_fqdn
  map          = google_certificate_manager_certificate_map.default[0].name
}

resource "google_dns_record_set" "default" {
  count        = var.create ? 1 : 0
  name         = google_certificate_manager_dns_authorization.default[0].dns_resource_record[0].name
  managed_zone = data.google_dns_managed_zone.default.name
  type         = google_certificate_manager_dns_authorization.default[0].dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.default[0].dns_resource_record[0].data]
}

# DNS A record for main Vault FQDN pointing to the LB IP
resource "google_dns_record_set" "vault_a" {
  count        = var.create && !var.use_gateway_api ? 1 : 0
  name         = "${var.vault_fqdn}."
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.default[0].address]
}

# ============================================================================
# mTLS endpoint certificate and DNS configuration
# ============================================================================

resource "google_certificate_manager_dns_authorization" "mtls" {
  count    = var.create && var.mtls_enabled && var.vault_mtls_fqdn != "" ? 1 : 0
  name     = "vault-mtls-cert-dnsauth-${var.unique_id}"
  location = "global"
  domain   = var.vault_mtls_fqdn
  type     = "FIXED_RECORD"
}

resource "google_certificate_manager_certificate" "mtls" {
  count    = var.create && var.mtls_enabled && var.vault_mtls_fqdn != "" ? 1 : 0
  name     = "vault-mtls-cert-${var.unique_id}"
  location = "global"

  managed {
    domains = [var.vault_mtls_fqdn]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.mtls[0].id
    ]
  }
}

resource "google_certificate_manager_certificate_map_entry" "mtls" {
  count        = var.create && var.mtls_enabled && var.vault_mtls_fqdn != "" ? 1 : 0
  name         = "vault-mtls-cert-map-entry-${var.unique_id}"
  certificates = [google_certificate_manager_certificate.mtls[0].id]
  hostname     = var.vault_mtls_fqdn
  map          = google_certificate_manager_certificate_map.default[0].name
}

# DNS record for mTLS certificate validation
resource "google_dns_record_set" "mtls_cert" {
  count        = var.create && var.mtls_enabled && var.vault_mtls_fqdn != "" ? 1 : 0
  name         = google_certificate_manager_dns_authorization.mtls[0].dns_resource_record[0].name
  managed_zone = data.google_dns_managed_zone.default.name
  type         = google_certificate_manager_dns_authorization.mtls[0].dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.mtls[0].dns_resource_record[0].data]
}

# DNS A record for mTLS FQDN pointing to the same LB IP
resource "google_dns_record_set" "mtls_a" {
  count        = var.create && var.mtls_enabled && var.vault_mtls_fqdn != "" ? 1 : 0
  name         = "${var.vault_mtls_fqdn}."
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.default[0].address]
}

# mTLS configuration for client certificate authentication
resource "google_certificate_manager_trust_config" "client_ca" {
  count       = var.create && var.mtls_enabled ? 1 : 0
  name        = "vault-client-ca-${var.unique_id}"
  location    = "global"
  description = "Trust config for Vault client certificate authentication"

  trust_stores {
    trust_anchors {
      pem_certificate = var.client_ca_pem
    }
  }
}

resource "google_network_security_server_tls_policy" "mtls" {
  count       = var.create && var.mtls_enabled ? 1 : 0
  name        = "vault-mtls-policy-${var.unique_id}"
  location    = "global"
  description = "mTLS policy for Vault client certificate authentication"

  mtls_policy {
    client_validation_mode         = "ALLOW_INVALID_OR_MISSING_CLIENT_CERT"
    client_validation_trust_config = google_certificate_manager_trust_config.client_ca[0].id
  }
}