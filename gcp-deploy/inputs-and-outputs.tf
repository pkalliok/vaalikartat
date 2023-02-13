
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

