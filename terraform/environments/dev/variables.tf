variable "aws_region" {
  description = "AWS region for all provisioned infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "todo-app-eks-dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the development VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "Diversified EC2 instance types for the EKS managed node group to maximize Spot availability"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t2.medium"]
}

variable "node_capacity_type" {
  description = "Capacity type for worker nodes (SPOT or ON_DEMAND)"
  type        = string
  default     = "SPOT"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "enable_load_balancer_controller" {
  description = "Enable deployment of the AWS Load Balancer Controller Helm chart (set to false during initial cluster bootstrap if needed)"
  type        = bool
  default     = true
}
