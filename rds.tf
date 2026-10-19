resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "aws_db_instance" "postgres" {
  identifier             = "vaultwarden-postgres"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "postgres"
  engine_version         = "18"
  instance_class         = "db.t4g.micro"
  db_name                = var.db_name
  username               = var.db_user
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_type           = "gp3"

  tags = { Name = "vaultwarden-db" }
}
