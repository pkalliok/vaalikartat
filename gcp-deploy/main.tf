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

