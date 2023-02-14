terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
}

provider "google" {
  credentials = file("gcloud-credentials.json")
  project     = var.gcp_project
  region      = var.gcp_region
  zone        = "${var.gcp_region}-c"
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

