terraform {
  backend "s3" {
    bucket         = "cyderes-tfstate-bucket"
    key            = "terraform/state"
    region         = "us-west-2"
    encrypt        = true
  }
}