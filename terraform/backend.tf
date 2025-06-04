terraform {
  backend "s3" {
    bucket         = "cyderes-tfstate-bucket"
    key            = "eks-cluster/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "cyderes-tfstate-lock"
  }
}