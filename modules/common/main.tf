###
# Generate random string id
###

resource "random_string" "suffix" {
  length  = 5
  lower   = true
  numeric = false
  special = false
  upper   = false
}

data "google_compute_zones" "available" {
  project = var.project
  region  = var.region
}

data "google_project" "current" {}


resource "google_project_service" "default" {
  for_each = toset([
    "cloudkms.googleapis.com",
    "certificatemanager.googleapis.com",
    "networksecurity.googleapis.com"
  ])

  project = var.project
  service = each.value

  disable_on_destroy = false

}