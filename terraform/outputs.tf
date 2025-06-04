output "eks_cluster_name" {
  value = "funny-synth-duck"
}

output "ecr_repository_name" {
  value = aws_ecr_repository.cyderes_webserver.name
}