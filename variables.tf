variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "aws_profile" {
  type    = string
  default = "zd-admin"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "db_name" {
  type    = string
  default = "vaultwarden"
}

variable "db_user" {
  type    = string
  default = "vaultwarden"
}
