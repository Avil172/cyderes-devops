output "cluster_name" {
  value = "funny-synth-duck"
}

output "cluster_endpoint" {
  value = data.aws_eks_cluster.cluster.endpoint
}

output "cluster_certificate_authority" {
  value = data.aws_eks_cluster.cluster.certificate_authority[0].data
}