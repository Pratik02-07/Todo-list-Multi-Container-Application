variable "cluster_name" {
  description = "Name of the EKS cluster for IAM role naming and scoping"
  type        = string
}

variable "tags" {
  description = "Common tags applied to IAM resources"
  type        = map(string)
  default     = {}
}
