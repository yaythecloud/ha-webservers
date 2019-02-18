### data ###

data "aws_availability_zones" "available" {}

### vpc variables ###

variable "environment" {
  description = "enter dev, stg, or prod"
  type = "string"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public-subnet-a" {
  default = "10.0.1.0/24"
}

variable "public-subnet-b" {
  default = "10.0.2.0/24"
}



