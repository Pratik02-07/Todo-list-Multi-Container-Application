# Development Environment (`dev`)

Orchestrates the complete Amazon EKS infrastructure stack for the Multi-Container Todo List application in `ap-south-1`.

## Included Modules
- **`networking`**: VPC, 2 public subnets, 2 private subnets, 1 NAT Gateway.
- **`iam`**: EKS cluster and node group IAM roles.
- **`eks`**: EKS Cluster (Kubernetes 1.37) and Managed Node Group with `SPOT` capacity.
- **`addons`**: `vpc-cni`, `coredns`, `kube-proxy`, and `aws-ebs-csi-driver` (with IRSA).
- **`aws-load-balancer-controller`**: Official Helm chart release with dedicated IRSA role and ServiceAccount.

## Deployment Instructions

### 1. Configure S3 Remote Backend
Create `backend.hcl` from `backend.hcl.example`:
```bash
cp backend.hcl.example backend.hcl
```

### 2. Configure Variables
Create `terraform.tfvars` from `terraform.tfvars.example`:
```bash
cp terraform.tfvars.example terraform.tfvars
```

### 3. Initialize and Apply
```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

> **Note on Initial Bootstrap (Staged Execution):**
> Because the `kubernetes` and `helm` providers authenticate to the EKS cluster within the same configuration, on a completely fresh deployment you can stage execution to guarantee cluster readiness:
> ```bash
> # Stage 1: Provision the base VPC, IAM roles, EKS Cluster, and Add-ons:
> terraform apply -var="enable_load_balancer_controller=false"
>
> # Stage 2: Enable and deploy the AWS Load Balancer Controller Helm chart:
> terraform apply
> ```

### 4. Connect with `kubectl`
Use the output command to configure your local kubeconfig:
```bash
$(terraform output -raw configure_kubectl)
kubectl get nodes -o wide
kubectl get pods -A
```

### 5. Clean Teardown
```bash
kubectl delete -k ../../../k8s/overlays/eks
terraform destroy
```
