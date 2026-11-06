variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes control plane version"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID where the cluster and nodes are provisioned"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the EKS control plane and worker nodes"
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "ARN of the IAM role for the EKS cluster control plane"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the IAM role for the EKS managed node group"
  type        = string
}

variable "instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "Capacity type for worker nodes (SPOT or ON_DEMAND)"
  type        = string
  default     = "SPOT"
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "disk_size" {
  description = "Root EBS volume size in GB for worker nodes"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Common tags applied to EKS resources"
  type        = map(string)
  default     = {}
}
