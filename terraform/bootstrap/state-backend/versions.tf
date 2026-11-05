terraform {
  # Minimum core engine requirements
  required_version = ">= 1.5.0"

  # Declares plugins that Terraform must download
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Allows updates within the v6.x line (e.g., 6.71.0)
    }
  }
}
