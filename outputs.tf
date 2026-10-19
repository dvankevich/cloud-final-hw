output "vaultwarden_url" {
  description = "Public URL to access Vaultwarden"
  value       = "http://${aws_lb.main.dns_name}"
}

output "rds_endpoint" {
  description = "RDS Endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}
