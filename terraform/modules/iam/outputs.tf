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

output "cluster_iam_policy_attachments" {
  description = "List of IAM policy attachment IDs for the EKS cluster role"
  value = [
    aws_iam_role_policy_attachment.cluster_policy.id,
    aws_iam_role_policy_attachment.cluster_vpc_controller.id,
  ]
}

output "node_iam_policy_attachments" {
  description = "List of IAM policy attachment IDs for the EKS node group role"
  value = [
    aws_iam_role_policy_attachment.node_worker.id,
    aws_iam_role_policy_attachment.node_cni.id,
    aws_iam_role_policy_attachment.node_registry.id,
  ]
}
