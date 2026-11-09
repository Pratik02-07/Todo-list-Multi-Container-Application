# Target Architecture & System Design

This document details the architectural principles, component interactions, trade-offs, and cloud topology of the **Todo List Multi-Container Application** on Amazon EKS.

---

## 1. High-Level Target Architecture

The platform architecture bridges modern cloud-native development with enterprise DevOps practices:

```
┌───────────────────────────────────────────────────────────────────────────┐
│                             AWS Cloud (ap-south-1)                        │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                Dedicated VPC (10.50.0.0/16)                         │  │
│  │                                                                     │  │
│  │   Public Subnets (10.50.1.0/24, 10.50.2.0/24)                       │  │
│  │   ┌─────────────────────────────────────────────────────────────┐   │  │
│  │   │ AWS Application Load Balancer (ALB)                         │   │  │
│  │   │  - Port 80 (HTTP) -> Redirect 443 (HTTPS)                   │   │  │
│  │   │  - Port 443 (HTTPS with AWS ACM TLS Certificate)            │   │  │
│  │   │  - AWS NAT Gateway (1x for Cost Optimization)               │   │  │
│  │   └──────────────────────────────┬──────────────────────────────┘   │  │
│  │                                  │                                  │  │
│  │   Private Subnets (10.50.10.0/24, 10.50.20.0/24)                    │  │
│  │   ┌─────────────────────────────────────────────────────────────┐   │  │
│  │   │ Amazon EKS Cluster (Kubernetes 1.37)                        │   │  │
│  │   │ Managed Node Group: 2x Spot Instances (t3.medium/t3a.medium)│   │  │
│  │   │                                                             │   │  │
│  │   │  Namespace: todo-app                                        │   │  │
│  │   │  ┌─────────────────────────┐   ┌──────────────────────────┐ │   │  │
│  │   │  │ Frontend Pods (Nginx)   │   │ Backend API Pods (Node)  │ │   │  │
│  │   │  │  - Static Web Host      ├──▶│  - Express REST API      │ │   │  │
│  │   │  │  - API Reverse Proxy    │   │  - Port 3000             │ │   │  │
│  │   │  │  - Port 80              │   │  - Non-Root (UID 1000)   │ │   │  │
│  │   │  │  - HPA: 2-6 Pods        │   │  - HPA: 2-6 Pods         │ │   │  │
│  │   │  └─────────────────────────┘   └─────────────┬────────────┘ │   │  │
│  │   │                                              │              │   │  │
│  │   │                                              ▼ (:27017)     │   │  │
│  │   │                                ┌──────────────────────────┐ │   │  │
│  │   │                                │ MongoDB StatefulSet      │ │   │  │
│  │   │                                │  - Headless Service      │ │   │  │
│  │   │                                │  - PersistentVolumeClaim │ │   │  │
│  │   │                                └─────────────┬────────────┘ │   │  │
│  │   └──────────────────────────────────────────────┼──────────────┘   │  │
│  │                                                  │                  │  │
│  │                                                  ▼                  │  │
│  │                                   Amazon EBS gp3 Volume (Encrypted) │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Design & Roles

| Tier | Technology | Key Design Decisions |
|---|---|---|
| **Edge & Routing** | AWS ALB + AWS Load Balancer Controller | Subnet autodiscovery, SSL termination, path-based routing, target group health probes mapped to `/ready`. |
| **Presentation** | Nginx 1.27-Alpine | Serves static assets with 7-day immutable caching; proxies `/api/*` and health probes to backend; enforces security headers. |
| **Application API** | Node.js 22 + Express | Stateless REST API, strict Zod input validation, structured JSON logging, graceful shutdown (`SIGTERM`/`SIGINT`). |
| **Persistence** | MongoDB 7.0 | Single-replica StatefulSet with headless Service, dynamic gp3 volume provisioning via EBS CSI Driver. |
| **Storage Class** | `ebs-gp3` | VolumeBindingMode: `WaitForFirstConsumer`, filesystem `ext4`, encrypted by default via AWS KMS. |

---

## 3. Key Engineering Decisions & Trade-offs

1. **StatefulSet vs. Managed DocumentDB / Atlas:**
   - *Decision:* Deployed MongoDB as an in-cluster StatefulSet backed by EBS gp3.
   - *Trade-off:* Eliminates managed database recurring costs (~$150+/month for AWS DocumentDB) for this development and portfolio showcase while proving mastery over Kubernetes StatefulSets, headless services, and storage classes.
2. **Spot Instances with Diversification:**
   - *Decision:* Configured EKS Managed Node Group with `capacity_type = "SPOT"` diversified across `t3.medium`, `t3a.medium`, and `t2.medium`.
   - *Trade-off:* Saves ~70% on EC2 compute costs while maintaining pod reliability via `PodDisruptionBudgets` (`minAvailable: 1`) and `topologySpreadConstraints` across AZs.
3. **Single NAT Gateway for Dev:**
   - *Decision:* Used 1 shared NAT Gateway across private subnets rather than 1 per AZ.
   - *Trade-off:* Reduces baseline VPC infrastructure cost by ~$32/month per additional NAT Gateway, fully acceptable for non-production environments.
4. **Terraform S3 Native State Locking:**
   - *Decision:* Adopted Terraform 1.10+ native lockfiles (`use_lockfile = true`) via S3 conditional writes.
   - *Trade-off:* Completely eliminates DynamoDB state locking tables and IAM table policies, simplifying state administration without sacrificing concurrency protection.
