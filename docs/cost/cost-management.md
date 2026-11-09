# Cloud Cost Management & Optimization Guide

This document details the cost estimation, cost-optimization strategies, and resource teardown procedures for the **Todo List Multi-Container Application** deployed on AWS in region `ap-south-1` (Mumbai).

---

## 1. Estimated Monthly Cost Breakdown (Dev Environment)

| Resource | Configuration | Purpose | Estimated Monthly Cost (USD) |
|---|---|---|:---:|
| **Amazon EKS Cluster** | Control Plane (1 cluster) | Kubernetes master API & etcd | ~$73.00 |
| **EC2 Worker Nodes** | 2x `t3.medium` (SPOT capacity) | Kubernetes compute workloads | ~$9.50 (~70% discount) |
| **AWS NAT Gateway** | 1x Shared NAT Gateway | Outbound Internet for private subnets | ~$32.40 |
| **Application Load Balancer** | 1x ALB (Internet-facing) | Ingress routing & SSL termination | ~$16.20 |
| **Amazon EBS Storage** | 1x 8Gi gp3 + 2x 20Gi Node EBS | MongoDB database & Node OS | ~$4.00 |
| **Amazon S3 State & Backups** | Versioned bucket + State Lockfile | Terraform state & DB backups | <$0.50 |
| **Total Estimated Cost** | — | — | **~$135.60 / month** (~$4.50 / day) |

---

## 2. Implemented Cost Optimization Strategies

1. **Spot Instances:**
   - Worker nodes utilize `SPOT` capacity with multiple fallback instance types (`t3.medium`, `t3a.medium`, `t2.medium`), cutting EC2 compute costs by ~70% compared to On-Demand.
2. **Single Shared NAT Gateway:**
   - Deployed a single NAT Gateway shared across both Availability Zones instead of provisioning one per AZ, saving ~$32/month.
3. **No External DynamoDB Tables:**
   - Using native S3 state locking (`use_lockfile = true`) saves unnecessary DynamoDB table provisioning and read/write capacity overhead.
4. **StatefulSet vs. Managed DB:**
   - Self-hosting MongoDB via a Kubernetes StatefulSet backed by an 8Gi gp3 EBS volume saves over ~$150/month compared to AWS DocumentDB.
5. **Horizontal Pod Autoscaling (HPA):**
   - Keeps base replica counts minimal (2 pods) and only scales up to 6 pods during genuine traffic spikes.

---

## 3. Safe Teardown & Resource Cleanup Procedures

When concluding development or tearing down infrastructure to eliminate AWS billing:

### Step 1: Teardown Application Workloads
```bash
# Deletes deployments, ingress, and ALB provisioned by AWS Load Balancer Controller
./scripts/cleanup.sh
```

### Step 2: Teardown Cloud Infrastructure (Terraform)
```bash
cd terraform/environments/dev
terraform destroy
```

### Step 3: Preserving State Bucket
The Terraform remote state S3 bucket in `terraform/bootstrap/state-backend` has `force_destroy = false` to prevent accidental deletion of historical state files and database backups.
