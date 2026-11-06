# Remote S3 state backend configuration
# Populated dynamically via: terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {}
}
