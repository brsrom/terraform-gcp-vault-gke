provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

provider "helm" {
  kubernetes = {
    host                   = "https://${google_container_cluster.autopilot.endpoint}"
    cluster_ca_certificate = base64decode(google_container_cluster.autopilot.master_auth.0.cluster_ca_certificate)
    token                  = data.google_client_config.current.access_token
  }
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.autopilot.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.autopilot.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}
