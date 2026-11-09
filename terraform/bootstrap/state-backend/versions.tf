terraform {
  # Minimum core engine requirements (>= 1.10.0 required for native S3 lockfiles)
  required_version = ">= 1.10.0"

  # Declares plugins that Terraform must download
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Allows updates within the v6.x line (e.g., 6.71.0)
    }
  }
}
