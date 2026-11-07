variable "aws_region" {
  description = "AWS region for the S3 state backend"
  type        = string
  default     = "ap-south-1"
}

variable "bucket_name" {
  description = "Globally unique name for the S3 remote state bucket"
  type        = string
  default     = "multi-container-todo-list-tf-state-backend-2026"
}
