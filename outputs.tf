output "vaultwarden_url" {
  description = "Public URL to access Vaultwarden"
  value       = "http://${aws_lb.main.dns_name}"
}

output "rds_endpoint" {
  description = "RDS Endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "admin_token" {
  description = "Generated admin token for Vaultwarden"
  value       = random_password.admin_token.result
  sensitive   = true
}
