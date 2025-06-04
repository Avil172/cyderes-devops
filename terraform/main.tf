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
  name = "devops/cyderes-nginx-2"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.cyderes_nginx.repository_url
}

resource "kubernetes_role" "deployer" {
  metadata {
    name      = "deployer-role"
    namespace = "cyderes"
  }

  rule {
    api_groups = ["", "apps"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "deployer_binding" {
  metadata {
    name      = "deployer-binding"
    namespace = "cyderes"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.deployer.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "ECR-user"
    api_group = "rbac.authorization.k8s.io"
  }
}