terraform {
  backend "s3" {
    bucket = "cyderes-tf-state"
    key    = "devops/webserver.tfstate"
    region = "us-west-2"
  }
}
