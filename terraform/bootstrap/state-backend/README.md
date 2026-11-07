# Remote State Backend Bootstrap

Provisions a secure, centralized AWS S3 bucket to store Terraform state for the Todo List infrastructure stack.

## Architecture

- **S3 Bucket**: Versioned and encrypted with AES256 server-side encryption.
- **S3 Native State Locking (`use_lockfile = true`)**: Leverages Terraform 1.10+ native lockfiles via S3 conditional writes, eliminating external DynamoDB dependencies.
- **Accidental Deletion Protection**: `force_destroy` is explicitly set to `false` to prevent accidental state deletion.
- **Public Access Blocked**: Strict S3 public access block applied.

## Deployment

```bash
cd terraform/bootstrap/state-backend
terraform init
terraform apply
```

Outputs provide the S3 bucket name and the backend snippet to configure `environments/dev/backend.hcl`.
