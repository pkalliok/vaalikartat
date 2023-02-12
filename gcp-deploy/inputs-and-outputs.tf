
variable "gcp_project" {
  default = "hasura_project"
}

output "hasura_pg_ip" {
  value = google_sql_database_instance.hasura-pg.public_ip_address
}

