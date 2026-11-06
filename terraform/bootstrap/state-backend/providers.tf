# Primary AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  # Automatically tag every resource created by this provider block
  default_tags {
    tags = {
      Environment = "Development"
      ManagedBy   = "Terraform"
      Project     = ""
    }
  }
}