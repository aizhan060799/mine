output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_certificate" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_oidc_provider_url" {
  description = "The URL of the EKS cluster's OIDC provider"
  value       = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}
output "eks_cluster_security_group_id" {
  description = "Security Group ID of the EKS cluster."
  value       = aws_security_group.eks_sg.id
}

output "worker_role_arn" {
  description = "IAM Role ARN for EKS worker nodes"
  value       = aws_iam_role.worker_role.arn
}