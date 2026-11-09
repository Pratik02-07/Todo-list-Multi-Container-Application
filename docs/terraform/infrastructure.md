# Infrastructure as Code (Terraform) Architecture

This document describes the modular Terraform infrastructure provisioned for the **Todo List Multi-Container Application** on AWS.

---

## 1. Directory Structure

```
terraform/
├── bootstrap/
│   └── state-backend/         # Centralized S3 bucket with native locking
├── environments/
│   └── dev/                   # Dev environment composition
└── modules/
    ├── networking/            # VPC, Subnets, NAT GW, ELB tags
    ├── iam/                   # Cluster, Node, IRSA IAM roles
    ├── eks/                   # EKS Control Plane, Spot Node Group, OIDC
    ├── addons/                # VPC-CNI, CoreDNS, Kube-Proxy, EBS CSI
    └── controllers/
        └── aws-load-balancer-controller/ # Helm Release + IRSA
```

---

## 2. Module Specifications

### A. `modules/networking`
- **VPC CIDR:** `10.50.0.0/16` (chosen to eliminate CIDR collisions).
- **Public Subnets:** `10.50.1.0/24` (AZ `ap-south-1a`), `10.50.2.0/24` (AZ `ap-south-1b`).
  - Tagged with `kubernetes.io/role/elb = 1` for Internet-facing ALB discovery.
- **Private Subnets:** `10.50.10.0/24` (AZ `ap-south-1a`), `10.50.20.0/24` (AZ `ap-south-1b`).
  - Tagged with `kubernetes.io/role/internal-elb = 1`.
- **Egress:** Single shared NAT Gateway in Public Subnet 1 for development cost reduction.

### B. `modules/iam`
- **EKS Cluster Role:** Attached with `AmazonEKSClusterPolicy` and `AmazonEKSVPCResourceController`.
- **EKS Managed Node Role:** Attached with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryReadOnly`.
- **OIDC Provider:** IAM OpenID Connect Provider bound to the EKS cluster issuer URL for IAM Roles for Service Accounts (IRSA).

### C. `modules/eks`
- **Kubernetes Version:** `1.37` (verified supported on AWS in `ap-south-1`).
- **Endpoint Access:** Public & Private API endpoint access enabled.
- **Node Group:** EKS Managed Node Group with capacity type `SPOT`.
- **Instance Types:** `["t3.medium", "t3a.medium", "t2.medium"]` for instance pool diversification.
- **Scaling:** Min: 2, Desired: 2, Max: 4 nodes.

### D. `modules/addons`
- **Core Add-ons:** `vpc-cni`, `coredns`, `kube-proxy`.
- **Storage Add-on:** `aws-ebs-csi-driver` bound to dedicated IAM IRSA role with `AmazonEBSCSIDriverPolicy`.

### E. `modules/controllers/aws-load-balancer-controller`
- Deploys the official AWS Load Balancer Controller Helm chart (`v1.8+`).
- Creates a dedicated ServiceAccount (`aws-load-balancer-controller` in `kube-system`) backed by an IAM role with the official ALB controller policy.
