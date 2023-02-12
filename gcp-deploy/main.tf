variable "gcp_project" {
  default = "hasura_project"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file("gcloud-credentials.json")
  project     = var.gcp_project
  region      = "europe-west1"
  zone        = "europe-west1-c"
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "vpc-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "hasura-pg" {
  name             = "hasura-pg"
  database_version = "POSTGRES_13"
  depends_on       = [google_service_networking_connection.private_vpc_connection]
  settings {
    tier = "db-custom-1-3840"
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc_network.id

    }
  }
}
