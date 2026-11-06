variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster and subnets are located"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the Load Balancer Controller"
  type        = string
  default     = "ap-south-1"
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA role trust"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https:// prefix)"
  type        = string
}

variable "chart_version" {
  description = "Helm chart version for aws-load-balancer-controller"
  type        = string
  default     = "1.8.1"
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default     = {}
}
