output "db_private_ip" {
  value       = google_sql_database_instance.main.private_ip_address
  description = "The private IP of the Postgres instance"
}