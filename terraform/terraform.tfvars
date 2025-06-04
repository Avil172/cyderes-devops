# terraform.tfvars
# Variable values for your Terraform project

aws_region     = "us-west-2"
cluster_name   = "cyderes-devops-cluster"
cluster_version = "1.27"

# Node group configuration
instance_type     = "t3.medium"
desired_capacity  = 2
min_capacity      = 1
max_capacity      = 4

# Network configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Project settings
environment   = "dev"
project_name  = "cyderes"

# Tags
common_tags = {
  Project     = "cyderes-devops"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "devops-team"
}