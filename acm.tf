# 1. Генерація приватного ключа RSA
resource "tls_private_key" "vaultwarden" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Генерація самопідписаного сертифіката для ALB DNS
resource "tls_self_signed_cert" "vaultwarden" {
  private_key_pem = tls_private_key.vaultwarden.private_key_pem

  subject {
    common_name  = aws_lb.main.dns_name
    organization = "Vaultwarden Lab"
  }

  validity_period_hours = 8760 # Дійсний 1 рік

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 3. Імпорт сертифіката в AWS ACM
resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.vaultwarden.private_key_pem
  certificate_body = tls_self_signed_cert.vaultwarden.cert_pem

  tags = { Name = "vaultwarden-selfsigned-cert" }
}
