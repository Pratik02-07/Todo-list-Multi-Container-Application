locals {
  common_tags = {
    Environment = var.environment
    Project     = "todo-list-multi-container"
    ManagedBy   = "Terraform"
  }
}
