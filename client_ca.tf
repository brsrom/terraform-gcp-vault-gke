locals {
  client_ca_pem = var.mtls_enabled ? file("${path.root}/certs/ca.pem") : ""
}
