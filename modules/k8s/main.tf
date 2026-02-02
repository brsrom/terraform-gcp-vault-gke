locals {
  cloud_armour_security_policy_name = "vault-policy-${var.unique_id}"
  lb_name                           = "lb-vault-${var.unique_id}"
}

data "google_client_config" "current" {}

data "google_project" "current" {
  project_id = var.project
}

resource "random_string" "suffix" {
  count   = var.create ? 1 : 0
  length  = 5
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "tls_private_key" "default" {
  count = var.create ? 1 : 0

  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "vault" {
  count = var.create ? 1 : 0

  private_key_pem = tls_private_key.default[0].private_key_pem

  dns_names    = var.dns_names
  ip_addresses = ["127.0.0.1"]

  subject {
    common_name  = var.domain
    organization = var.organization
  }

  validity_period_hours = 24 * 365

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_namespace_v1" "default" {
  count = var.create ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "tls" {
  count = var.create ? 1 : 0

  metadata {
    name      = var.tls_secret_name
    namespace = kubernetes_namespace_v1.default[0].metadata.0.name
  }
  data = {
    (var.tls_secret_crt) = tls_self_signed_cert.vault[0].cert_pem
    (var.tls_secret_key) = tls_self_signed_cert.vault[0].private_key_pem
  }
  type = "kubernetes.io/tls"
}

resource "kubernetes_secret_v1" "tls_ca" {
  count = var.create ? 1 : 0

  metadata {
    name      = var.tls_ca_secret_name
    namespace = kubernetes_namespace_v1.default[0].metadata.0.name
  }
  data = {
    (var.tls_ca_secret_crt) = tls_self_signed_cert.vault[0].cert_pem
  }
}

# Create vault enterprise license secret if set
resource "kubernetes_secret_v1" "license" {
  count = var.create && var.vault_license != null ? 1 : 0

  metadata {
    name      = var.vault_license_secret_name
    namespace = kubernetes_namespace_v1.default[0].metadata.0.name
  }
  data = {
    (var.vault_license_secret_key) = var.vault_license
  }
}

resource "google_compute_global_address" "default" {
  count = var.create ? 1 : 0
  name  = local.lb_name
}

resource "google_kms_key_ring" "vault" {
  count    = var.create ? 1 : 0
  name     = "vault-keyring-${var.unique_id}-${random_string.suffix[0].result}"
  location = var.region
}

resource "google_kms_crypto_key" "vault" {
  count           = var.create ? 1 : 0
  name            = "vault-key-${var.unique_id}"
  key_ring        = google_kms_key_ring.vault[0].id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "vault" {
  count        = var.create ? 1 : 0
  account_id   = "vault-kms-${var.unique_id}"
  display_name = "Vault KMS Service Account"
  description  = "Service account for Vault to access Cloud KMS for auto-unseal"
  project      = var.project
}

resource "google_kms_crypto_key_iam_binding" "vault_encrypt_decrypt" {
  count         = var.create ? 1 : 0
  crypto_key_id = google_kms_crypto_key.vault[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_service_account.vault[0].email}",
  ]
}

resource "google_kms_crypto_key_iam_binding" "vault_viewer" {
  count         = var.create ? 1 : 0
  crypto_key_id = google_kms_crypto_key.vault[0].id
  role          = "roles/cloudkms.viewer"

  members = [
    "serviceAccount:${google_service_account.vault[0].email}",
  ]
}

resource "google_service_account_iam_binding" "vault_workload_identity" {
  count              = var.create ? 1 : 0
  service_account_id = google_service_account.vault[0].name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project}.svc.id.goog[${kubernetes_namespace_v1.default[0].metadata.0.name}/vault]",
  ]
}

resource "kubernetes_service_account_v1" "vault" {
  count = var.create ? 1 : 0

  metadata {
    name      = "vault"
    namespace = kubernetes_namespace_v1.default[0].metadata.0.name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.vault[0].email
    }
  }
}

resource "helm_release" "vault_prereqs" {
  count = var.create ? 1 : 0

  name      = "vault-prereqs"
  chart     = "${path.root}/charts/vault_prereqs"
  namespace = kubernetes_namespace_v1.default[0].metadata.0.name

  set = [
    {
      name  = "backend_config_name"
      value = var.vault_backend_config
    },
    {
      name  = "cloud_armor_security_policy_name"
      value = local.cloud_armour_security_policy_name
    },
    {
      name  = "fqdn"
      value = var.vault_fqdn
    },
    {
      name  = "certificate_map_name"
      value = google_certificate_manager_certificate_map.default[0].name
    },
    {
      name  = "namespace"
      value = kubernetes_namespace_v1.default[0].metadata.0.name
    },
    {
      name  = "lb_ip_address_name"
      value = google_compute_global_address.default[0].name
    },
    {
      name  = "gcp_project"
      value = var.project
    },
    {
      name  = "mtls_enabled"
      value = tostring(var.mtls_enabled)
    },
    {
      name  = "server_tls_policy_name"
      value = var.mtls_enabled ? google_network_security_server_tls_policy.mtls[0].id : ""
    },
    {
      name  = "use_gateway_api"
      value = tostring(var.use_gateway_api)
    }
  ]
}

resource "helm_release" "vault" {
  count      = var.create ? 1 : 0
  name       = "vault"
  repository = "helm.releases.hashicorp.com"
  chart      = "hashicorp/vault"
  version    = var.vault_chart_version

  namespace = kubernetes_namespace_v1.default[0].metadata.0.name
  values = [
    "${templatefile("${path.module}/templates/vault_values.tftpl",
      {
        lb_ip_address_name        = google_compute_global_address.default[0].name
        managed_certificate_name  = var.managed_certificate_name
        vault_backend_config      = var.vault_backend_config
        vault_license_secret_name = var.vault_license != null ? var.vault_license_secret_name : ""
        vault_license_secret_key  = var.vault_license_secret_key
        vault_repository          = var.vault_repository
        vault_version_tag         = var.vault_version_tag
        fqdn                      = var.vault_fqdn
        project                   = var.project
        region                    = var.region
        kms_key_ring              = google_kms_key_ring.vault[0].name
        kms_crypto_key            = google_kms_crypto_key.vault[0].name
        vault_log_level           = var.vault_log_level
    })}"
  ]

  depends_on = [
    helm_release.vault_prereqs
  ]
}

resource "google_compute_security_policy" "whitelist" {
  count = var.create && var.cloud_armour_enabled ? 1 : 0
  name  = local.cloud_armour_security_policy_name

  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.cloud_armour_whitelist_cidrs
      }
    }
    description = "Allow access to whitelisted IPs"
  }

  rule {
    action   = "throttle"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 10
        interval_sec = "60"
      }
    }
    description = "Rate limit all other connections"
  }

  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default deny rule"
  }

  timeouts {
    delete = "30m"
  }
}
