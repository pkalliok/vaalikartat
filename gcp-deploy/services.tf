
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

resource "google_sql_user" "hasura-pg-root" {
  name     = "root"
  instance = google_sql_database_instance.hasura-pg.name
  password = var.root_database_password
}
