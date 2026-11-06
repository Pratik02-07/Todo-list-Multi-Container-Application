output "cluster_role_arn" {
  description = "ARN of the IAM role used by the EKS cluster control plane"
  value       = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  description = "Name of the IAM role used by the EKS cluster control plane"
  value       = aws_iam_role.cluster.name
}

output "node_role_arn" {
  description = "ARN of the IAM role used by the EKS managed node group"
  value       = aws_iam_role.node_group.arn
}

output "node_role_name" {
  description = "Name of the IAM role used by the EKS managed node group"
  value       = aws_iam_role.node_group.name
}
