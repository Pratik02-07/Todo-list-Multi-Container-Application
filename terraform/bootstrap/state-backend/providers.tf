# Primary AWS Provider Configuration
provider "aws" {
  region = "ap-south-1"
  # Automatically tag every resource created by this provider block
  default_tags {
    tags = {
      Environment = "Development"
      ManagedBy   = "Terraform"
      Project     = ""
    }
  }
}