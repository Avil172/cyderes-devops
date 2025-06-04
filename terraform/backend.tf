terraform {
  backend "s3" {
    bucket         = "cyderes-tf-state"
    key            = "terraform/state"
    region         = "us-west-2"
    encrypt        = true
  }
}