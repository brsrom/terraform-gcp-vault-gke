resource "google_service_account" "gke" {
  account_id   = "gke-${module.common.unique_id}"
  display_name = "GKE Service Account"
  description  = "Service account for GKE cluster nodes"
  project      = var.project
}

resource "google_container_cluster" "autopilot" {
  name     = local.gke_cluster_name
  location = var.region

  enable_autopilot = true
  networking_mode  = "VPC_NATIVE"

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke.email
    }
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes   = true
    master_ipv4_cidr_block = "172.16.0.32/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = local.management_ip
    }
  }

  network    = module.network.network.self_link
  subnetwork = module.network.subnetworks["gke"].self_link

  deletion_protection = false

  depends_on = [module.network]

  timeouts {
    delete = "30m"
  }
}

resource "google_project_iam_member" "gke" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer"
  ])
  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke.email}"
}
