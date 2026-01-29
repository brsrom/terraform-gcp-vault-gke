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
  matcher      = "PRIMARY"
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