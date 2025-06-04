provider "aws" {
  region = "us-west-2"
}

data "aws_eks_cluster" "cluster" {
  name = "funny-synth-duck"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "funny-synth-duck"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

resource "aws_ecr_repository" "cyderes_nginx" {
  name = "devops/cyderes-nginx"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.cyderes_nginx.repository_url
}