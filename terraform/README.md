# ☁️ Multi-Container Todo App — Terraform Infrastructure

This directory contains the production-ready, modular **Terraform** configuration to provision and manage the **Amazon EKS (Elastic Kubernetes Service)** platform on AWS for the Multi-Container Todo List application.

---

## 🏗️ Architecture & Module Flow

The infrastructure is decoupled into reusable modules and orchestrated via environment-specific root configurations with remote state management:

```
                               ┌──────────────────────────────────────────────────┐
                               │       Remote State Backend (Bootstrap)           │
                               │  - S3 Bucket (Encrypted, Versioned, Private)     │
                               │  - DynamoDB Table (State Locking)                │
                               └────────────────────────┬─────────────────────────┘
                                                        │
                                                        ▼
                               ┌──────────────────────────────────────────────────┐
                               │                environments/dev                  │
                               │           (Environment Orchestration)            │
                               └──────┬────────────┬────────────┬───────────┬─────┘
                                      │            │            │           │
             ┌────────────────────────┘            │            │           └────────────────────────┐
             ▼                                     ▼            ▼                                    ▼
┌─────────────────────────┐           ┌──────────────────┐ ┌───────────────────┐        ┌─────────────────────────┐
│   modules/networking    │           │   modules/iam    │ │    modules/eks    │        │    modules/controllers  │
│ - VPC & Multi-AZ Subnets│           │ - Cluster Role   │ │ - EKS Control     │        │ - AWS Load Balancer     │
│ - NAT & Internet GW     │           │ - Node Group Role│ │   Plane           │        │   Controller (Helm+IRSA)│
│ - ELB/ALB Subnet Tags   │           │ - OIDC & IRSA    │ │ - Managed Nodes   │        └─────────────────────────┘
└─────────────────────────┘           └──────────────────┘ └─────────┬─────────┘
                                                                     │
                                                                     ▼
                                                          ┌───────────────────┐
                                                          │  modules/addons   │
                                                          │ - VPC-CNI, CoreDNS│
                                                          │ - kube-proxy      │
                                                          │ - AWS EBS CSI     │
                                                          └───────────────────┘
```

---

## 📁 Directory Structure

```
terraform/
│
├── README.md                                # Root infrastructure documentation (this file)
│
├── bootstrap/
│   └── state-backend/                       # One-time bootstrap for remote state storage
│       ├── versions.tf                      # Terraform & AWS provider requirements
│       ├── providers.tf                     # AWS provider definition
│       ├── main.tf                          # S3 bucket + DynamoDB lock table resources
│       ├── variables.tf                     # Region, bucket name, and table name inputs
│       ├── outputs.tf                       # S3 bucket, DynamoDB table, backend snippet
│       └── README.md                        # Bootstrap module guide
│
├── environments/
│   └── dev/                                 # Development environment root composition
│       ├── backend.tf                       # S3 remote state backend configuration
│       ├── backend.hcl.example              # Sample backend credentials/config
│       ├── versions.tf                      # Terraform and provider version constraints
│       ├── providers.tf                     # AWS, Kubernetes, Helm providers
│       ├── main.tf                          # Instantiates networking, IAM, EKS, addons
│       ├── variables.tf                     # Environment input variables
│       ├── locals.tf                        # Common tags, resource prefixes, calculated values
│       ├── outputs.tf                       # EKS cluster endpoint, OIDC ARN, VPC ID, etc.
│       ├── terraform.tfvars.example         # Example input values for dev environment
│       └── README.md                        # Dev environment deployment guide
│
└── modules/
    │
    ├── networking/                          # VPC, Subnets (Public/Private), NAT GW, Route Tables
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    │
    ├── iam/                                 # IAM roles & policies for EKS, Nodes, and IRSA
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    │
    ├── eks/                                 # EKS Cluster control plane and managed node groups
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    │
    ├── addons/                              # EKS managed add-ons (VPC-CNI, CoreDNS, EBS CSI, etc.)
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    │
    └── controllers/
        └── aws-load-balancer-controller/    # Helm & IRSA integration for ALB Ingress Controller
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            └── README.md
```

---

## 🧩 Modules Summary

| Module | Purpose | Key Resources |
|---|---|---|
| **`bootstrap/state-backend`** | Manages remote state prerequisites | S3 Bucket (Encrypted, Versioned), DynamoDB Table |
| **`modules/networking`** | Multi-AZ network foundation | VPC, Public & Private Subnets, IGW, NAT Gateways, ELB Tags |
| **`modules/iam`** | Security and identity boundaries | Cluster Role, Worker Node Role, IAM OIDC Provider, IRSA Policies |
| **`modules/eks`** | Kubernetes platform core | EKS Cluster, Node Groups, Security Groups, Cluster Logging |
| **`modules/addons`** | Cluster infrastructure add-ons | `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver` |
| **`modules/controllers/aws-load-balancer-controller`** | Ingress and ALB management | Controller ServiceAccount, IRSA Role, Helm Release |

---

## 🛠️ Prerequisites

Before executing Terraform, make sure you have installed:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.5.0`
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with administrative credentials (`aws configure`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for interacting with the Kubernetes cluster
- [Helm v3+](https://helm.sh/docs/intro/install/) (if deploying chart dependencies directly)

Default AWS Region: **`ap-south-1`** (Mumbai) — configurable via variables.

---

## 🚀 Step-by-Step Deployment Workflow

### Step 1: Bootstrap the Remote State Backend

Provision the dedicated S3 bucket and DynamoDB table for state storage and locking:

```bash
cd terraform/bootstrap/state-backend

# Initialize and apply bootstrap
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Take note of the outputs:
- `s3_bucket_name`
- `dynamodb_table_name`
- `backend_config_snippet`

---

### Step 2: Configure the Environment Backend & Variables

Navigate to the `dev` environment directory:

```bash
cd ../../environments/dev
```

1. **Configure remote backend**:  
   Create `backend.hcl` from `backend.hcl.example` (or configure `backend.tf`):
   ```hcl
   bucket         = "multi-container-todo-list-tf-state-backend-2026"
   key            = "dev/terraform.tfstate"
   region         = "ap-south-1"
   dynamodb_table = "multi-container-todo-list-tf-locks"
   encrypt        = true
   ```

2. **Set variable values**:  
   Copy `terraform.tfvars.example` to `terraform.tfvars` and customize your settings:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

---

### Step 3: Initialize and Deploy EKS Infrastructure

```bash
# Initialize Terraform with the S3 backend
terraform init -backend-config=backend.hcl

# Review execution plan
terraform plan -out=tfplan

# Apply the infrastructure
terraform apply tfplan
```

---

### Step 4: Configure `kubectl` & Verify Cluster Access

Once Terraform completes successfully, update your local kubeconfig:

```bash
aws eks update-kubeconfig --region ap-south-1 --name <cluster_name>
```

Verify connectivity:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

---

## 🔒 Security & Best Practices

- **State File Security**: State files in S3 are protected with AES256 server-side encryption, versioning, and public access blocks.
- **State Locking**: Concurrent applies are prevented using DynamoDB table locking.
- **Least-Privilege IRSA**: Pods assume AWS IAM roles using IAM Roles for Service Accounts (IRSA) rather than relying on broad EC2 node instance profile permissions.
- **Network Isolation**: Worker nodes and application databases run strictly in private subnets with NAT Gateway egress; only external ALBs reside in public subnets.
- **Subnet Tagging for EKS**:
  - Public Subnets: `kubernetes.io/role/elb = 1`
  - Private Subnets: `kubernetes.io/role/internal-elb = 1`

---

## 🧹 Teardown Order

To destroy resources cleanly without leaving orphan cloud resources:

1. **Delete Kubernetes Workloads & Ingresses first**:
   ```bash
   kubectl delete -k k8s/overlays/eks
   ```
   *(Ensure AWS Load Balancer Controller has deleted any provisioned ALBs before destroying the VPC).*

2. **Destroy Environment Infrastructure**:
   ```bash
   cd terraform/environments/dev
   terraform destroy
   ```

3. **Destroy Bootstrap State Backend (Optional)**:
   ```bash
   cd ../../bootstrap/state-backend
   terraform destroy
   ```

