
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

resource "random_password" "hasura_pg_root_password" {
  length  = 20
  special = false
}

resource "google_sql_user" "hasura-pg-root" {
  name     = "root"
  instance = google_sql_database_instance.hasura-pg.name
  password = random_password.hasura_pg_root_password.result
}

resource "google_compute_subnetwork" "hasura_connector_subnet" {
  name          = "hasura-connector-subnet"
  ip_cidr_range = "10.2.0.0/28"
  network       = google_compute_network.vpc_network.id
}

resource "google_vpc_access_connector" "hasura_connector" {
  name = "hasura-connector"
  subnet {
    name = google_compute_subnetwork.hasura_connector_subnet.name
  }
  machine_type = "f1-micro"
}

resource "random_password" "hasura_admin_key" {
  length  = 20
  special = false
}

resource "google_cloud_run_service" "hasura" {
  name     = "hasura-service"
  location = var.gcp_region
  template {
    spec {
      containers {
        image = var.hasura_image
        env {
          name  = "HASURA_GRAPHQL_METADATA_DATABASE_URL"
          value = "postgres://root:${random_password.hasura_pg_root_password.result}@${google_sql_database_instance.hasura-pg.private_ip_address}:5432/hasura"
        }
        env {
          name  = "PG_DATABASE_URL"
          value = "postgres://root:${random_password.hasura_pg_root_password.result}@${google_sql_database_instance.hasura-pg.private_ip_address}:5432/vaalidata"
        }
        env {
          name  = "HASURA_GRAPHQL_ENABLE_CONSOLE"
          value = "true"
        }
        env {
          name  = "HASURA_GRAPHQL_ADMIN_SECRET"
          value = random_password.hasura_admin_key.result
        }
      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"        = "2"
        "run.googleapis.com/client-name"          = "terraform"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.hasura_connector.name
        "run.googleapis.com/vpc-access-egress"    = "all-traffic"
        # "run.googleapis.com/cloudsql-instances"   = google_sql_database_instance.hasura-pg.connection_name
      }
    }
  }
}

resource "google_cloud_run_service_iam_member" "run_all_users" {
  service  = google_cloud_run_service.hasura.name
  location = google_cloud_run_service.hasura.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
