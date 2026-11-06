variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA role trust"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https:// prefix)"
  type        = string
}

variable "tags" {
  description = "Common tags applied to add-on resources"
  type        = map(string)
  default     = {}
}
