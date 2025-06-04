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

resource "aws_ecr_repository" "cyderes_webserver" {
  name                 = "cyderes-webserver"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "kubernetes_namespace" "cyderes" {
  metadata {
    name = "cyderes"
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.cyderes_webserver.repository_url
}

output "eks_cluster_endpoint" {
  value = data.aws_eks_cluster.cluster.endpoint
}