output "s3_bucket_name" {
  description = "Name of the S3 bucket for remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "backend_config_snippet" {
  description = "Backend configuration snippet for environment main.tf or backend.hcl"
  value       = <<EOF
terraform {
  backend "s3" {
    bucket       = "${aws_s3_bucket.terraform_state.id}"
    key          = "dev/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  }
}
EOF
}
