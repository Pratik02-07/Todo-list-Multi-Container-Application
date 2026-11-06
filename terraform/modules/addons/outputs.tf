output "addon_names" {
  description = "List of managed EKS add-ons deployed"
  value = [
    aws_eks_addon.vpc_cni.addon_name,
    aws_eks_addon.coredns.addon_name,
    aws_eks_addon.kube_proxy.addon_name,
    aws_eks_addon.ebs_csi.addon_name,
  ]
}

output "ebs_csi_role_arn" {
  description = "ARN of the IAM role used by the Amazon EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}
