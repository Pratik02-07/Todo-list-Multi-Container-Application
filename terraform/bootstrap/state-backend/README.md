# Remote State Backend Bootstrap

Provisions a secure, centralized AWS S3 bucket to store Terraform state for the Todo List infrastructure stack.

## Architecture & Features

- **S3 Bucket**: Versioned and encrypted with AES256 server-side encryption.
- **S3 Native State Locking (`use_lockfile = true`)**: Leverages Terraform 1.10+ native lockfiles via S3 conditional writes (`PutObject` with conditional checks), completely eliminating external DynamoDB table requirements.
- **Accidental Deletion Protection**: `force_destroy` is explicitly set to `false` to prevent accidental state deletion during teardown.
- **Public Access Blocked**: Strict S3 public access block applied across all four AWS S3 block settings.
- **TLS Enforced**: Bucket policy strictly denies non-HTTPS requests (`aws:SecureTransport: "false"`).

## Prerequisites

- **Terraform**: `>= 1.10.0` (required for S3 native state locking support).
- **AWS CLI**: Authenticated with credentials having permissions to manage S3 buckets and policies.

## Deployment

```bash
cd terraform/bootstrap/state-backend
terraform init
terraform apply
```

Outputs will provide the exact S3 bucket name and backend configuration snippet needed for `terraform/environments/dev/backend.hcl`.

---

## State Recovery & Version Restoration Procedures

Because S3 bucket versioning is enabled on the state bucket, any state corruption, accidental overwrite, or failed partial apply can be rolled back to a known good state.

### 1. Inspect State Versions
List previous versions of the state file in S3:
```bash
aws s3api list-object-versions \
  --bucket "<your-state-bucket-name>" \
  --prefix "dev/terraform.tfstate" \
  --query "Versions[].{VersionId:VersionId,LastModified:LastModified,IsLatest:IsLatest}" \
  --output table
```

### 2. Download and Verify a Specific Version
```bash
aws s3api get-object \
  --bucket "<your-state-bucket-name>" \
  --key "dev/terraform.tfstate" \
  --version-id "<target-version-id>" \
  recovered-terraform.tfstate

# Inspect state content
terraform state list -state=recovered-terraform.tfstate
```

### 3. Restore Previous State Version
Copy the recovered state file back as the active state object:
```bash
aws s3 cp recovered-terraform.tfstate "s3://<your-state-bucket-name>/dev/terraform.tfstate"
```

### 4. Handling Stale S3 Native Lockfiles
If a CI/CD runner crashes mid-apply, Terraform native S3 locking creates a `.tflock` object next to the state key (`dev/terraform.tfstate.tflock`).
To clear a stuck lock after verifying no other process is running:
```bash
# Option A: Standard Terraform force unlock
terraform force-unlock <lock-id>

# Option B: Remove stale S3 lock object directly if unlock fails
aws s3 rm "s3://<your-state-bucket-name>/dev/terraform.tfstate.tflock"
```
