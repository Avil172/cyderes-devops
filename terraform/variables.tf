variable "region" {
  default = "us-west-2"
}

variable "ami" {
  description = "AMI ID for EC2"
}

variable "instance_type" {
  default = "t2.micro"
}
