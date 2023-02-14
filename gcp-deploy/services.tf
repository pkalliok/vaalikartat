
resource "google_sql_database_instance" "hasura-pg" {
  name                = "hasura-pg"
  database_version    = "POSTGRES_13"
  deletion_protection = false
  settings {
    tier = "db-custom-1-3840"
    ip_configuration {
      ipv4_enabled = true
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

resource "random_password" "hasura_admin_key" {
  length  = 20
  special = false
}

resource "google_service_account" "hasura_cloudrun_sa" {
  account_id = "hasura-cloudrun-sa"
}

resource "google_project_iam_binding" "allow_hasura_sql" {
  project = var.gcp_project
  role    = "roles/cloudsql.client"
  members = [
    google_service_account.hasura_cloudrun_sa.member
  ]
}

resource "google_cloud_run_service" "hasura" {
  name       = "hasura-service"
  location   = var.gcp_region
  depends_on = [google_project_iam_binding.allow_hasura_sql]
  template {
    spec {
      service_account_name = google_service_account.hasura_cloudrun_sa.email
      containers {
        image = var.hasura_image
        env {
          name  = "HASURA_GRAPHQL_METADATA_DATABASE_URL"
          value = "postgres://root:${random_password.hasura_pg_root_password.result}@/hasura?host=/cloudsql/${google_sql_database_instance.hasura-pg.connection_name}"
        }
        env {
          name  = "PG_DATABASE_URL"
          value = "postgres://root:${random_password.hasura_pg_root_password.result}@/vaalidata?host=/cloudsql/${google_sql_database_instance.hasura-pg.connection_name}"
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
        "autoscaling.knative.dev/maxScale"      = "2"
        "run.googleapis.com/client-name"        = "terraform"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.hasura-pg.connection_name
        # "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.hasura_connector.name
        # "run.googleapis.com/vpc-access-egress"    = "all-traffic"
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
