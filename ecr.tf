resource "aws_ecr_repository" "vaultwarden" {
  name                 = "vaultwarden-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "vaultwarden-ecr" }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.vaultwarden.repository_url
}
