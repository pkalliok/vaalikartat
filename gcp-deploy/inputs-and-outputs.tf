
variable "gcp_project" {
  default = "hasura_project"
}

variable "root_database_password" {}

variable "gcp_region" {
  default = "europe-west1"
}

variable "hasura_image" {}

output "hasura_pg_ip" {
  value = google_sql_database_instance.hasura-pg.public_ip_address
}

output "hasura_pg_root_password" {
  value     = random_password.hasura_pg_root_password.result
  sensitive = true
}

output "hasura_admin_key" {
  value     = random_password.hasura_admin_key.result
  sensitive = true
}

output "hasura_url" {
  value = google_cloud_run_service.hasura.status.0.url
}
