variable "region" {
  default = "us-east-1"
}

variable "environment" {
  default = "development"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = []
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = []
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = []
}

variable "vpc_cidr_block" {
    description = "CIDR range for VPC"
    type = string
    default = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
    description = "CIDR ranges for public subnets"
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
    description = "CIDR ranges for public subnets"
    type = list(string)
    default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "owner_name" {
  type = string
  default = "michaeldbianchi@gmail.com"
}