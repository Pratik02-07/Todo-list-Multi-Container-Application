# ── Networking Outputs ────────────────────────────────────────────────────────
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

# ── EKS Outputs ───────────────────────────────────────────────────────────────
output "cluster_name" {
  description = "Name of the provisioned EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint URL of the EKS Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = module.eks.cluster_security_group_id
}

output "node_group_id" {
  description = "ID of the managed worker node group"
  value       = module.eks.node_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider used for IRSA"
  value       = module.eks.oidc_provider_arn
}

# ── Kubernetes Access Helper ──────────────────────────────────────────────────
output "configure_kubectl" {
  description = "CLI command to configure local kubectl context for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# ── Add-ons & Controller Outputs ──────────────────────────────────────────────
output "installed_addons" {
  description = "List of managed add-ons deployed to the cluster"
  value       = module.addons.addon_names
}

output "alb_controller_release_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = module.aws_load_balancer_controller.release_status
}
