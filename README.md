# 📝 Todo List — End-to-End AWS EKS DevOps Multi-Container Platform

> A production-grade, portfolio-ready DevOps engineering project showcasing a complete full-stack multi-container application delivered to **Amazon EKS (Elastic Kubernetes Service)** using **Terraform**, **Docker**, **Kubernetes (Kustomize)**, and **GitHub Actions CI/CD**.
>
> Grounded in the [roadmap.sh Multi-Container Service](https://roadmap.sh/projects/multi-container-service) specification and expanded into an end-to-end cloud-native delivery pipeline.

---

## 🏗️ Architecture & Cloud Topology

The platform decouples presentation, application logic, persistence, infrastructure, and delivery pipelines with defense-in-depth security:

```
[ Internet / Clients ]
         │
         ▼ (HTTPS :443 / HTTP :80)
┌─────────────────────────────────────────────────────────────┐
│ AWS Application Load Balancer (ALB)                         │
└──────────────────────────┬──────────────────────────────────┘
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
┌──────────────────────────┐  ┌───────────────────────────────┐
│ Frontend Pods (Nginx)    │  │ Backend API Pods (Express)    │
│  - Static Asset Delivery │  │  - REST API (:3000)           │
│  - API Reverse Proxy     │  │  - Zod Request Validation     │
│  - Non-Root Execution    │  │  - Graceful Shutdown Handlers │
└────────────┬─────────────┘  │  - Probes (/health, /ready)   │
             │                └──────────────┬────────────────┘
             └───────────────────────────────┤
                                             ▼ (:27017)
                              ┌───────────────────────────────┐
                              │ MongoDB Database (StatefulSet)│
                              │  - Dedicated Headless Service │
                              │  - AWS EBS gp3 Storage Class  │
                              └───────────────────────────────┘
```

---

## 📚 Technical Documentation Hub

Comprehensive architectural, operational, and deployment guides are organized under [`docs/`](docs/):

| Area | Documentation Link | Description |
|---|---|---|
| **Architecture** | [`docs/architecture/architecture.md`](docs/architecture/architecture.md) | High-level topology, component roles, design decisions & trade-offs |
| **Local Development** | [`docs/local-development/setup.md`](docs/local-development/setup.md) | Step-by-step local development using Docker Compose and Kind |
| **Containerization** | [`docs/docker/containerization.md`](docs/docker/containerization.md) | Multi-stage Docker builds, non-root users & OCI labeling standards |
| **Infrastructure** | [`docs/terraform/infrastructure.md`](docs/terraform/infrastructure.md) | Terraform modules (networking, IAM, EKS, add-ons, ALB controller) |
| **Kubernetes** | [`docs/kubernetes/deployment.md`](docs/kubernetes/deployment.md) | Kustomize overlays, Deployments, StatefulSets, HPA, and NetworkPolicies |
| **CI/CD Automation** | [`docs/cicd/pipeline.md`](docs/cicd/pipeline.md) | GitHub Actions CI/CD workflows, AWS OIDC authentication, and automated rollback |
| **DevSecOps** | [`docs/security/security.md`](docs/security/security.md) | Security hardening, Trivy/Checkov scanning, Secrets Manager, and NetworkPolicies |
| **Observability** | [`docs/monitoring/monitoring.md`](docs/monitoring/monitoring.md) | Prometheus metrics, CloudWatch log streams, Grafana dashboards, and alerting |
| **Database Recovery** | [`docs/operations/backup-restore.md`](docs/operations/backup-restore.md) | Automated S3 database backups (CronJob) and step-by-step restoration |
| **Deployment Rollback**| [`docs/operations/rollback.md`](docs/operations/rollback.md) | Automated pipeline rollbacks and manual operator runbook |
| **Troubleshooting** | [`docs/operations/troubleshooting.md`](docs/operations/troubleshooting.md) | Diagnostic runbooks for CrashLoopBackOff, Pending PVCs, and ALB 502/504 |
| **Cost Management** | [`docs/cost/cost-management.md`](docs/cost/cost-management.md) | AWS cost estimation, Spot instance savings, single NAT GW, and cleanup |

---

## ⚡ Quick Start

### 1. Local Development (Docker Compose)
```bash
cp .env.example .env
docker compose up --build -d
curl http://localhost/health
```

### 2. Run Test & Code Quality Suite
```bash
./scripts/test.sh
```

### 3. Deploy to Amazon EKS (AWS)
```bash
# 1. Bootstrap S3 Remote State Backend (with native S3 locking)
cd terraform/bootstrap/state-backend && terraform init && terraform apply

# 2. Provision AWS EKS Infrastructure
cd ../../environments/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply

# 3. Deploy Application Overlay
kubectl apply -k k8s/overlays/eks
```

---

## 🛠️ Technology Stack Summary

- **Frontend:** Nginx 1.27 + Modern Dark-Mode UI (Vanilla JS, CSS3, HTML5)
- **Backend:** Node.js 22 LTS + Express + Mongoose + Zod Validation
- **Database:** MongoDB 7.0 (Kubernetes StatefulSet with AWS EBS gp3 volume)
- **Container Registry:** Amazon ECR / Docker Hub
- **Cloud Infrastructure:** Amazon Web Services (AWS `ap-south-1`)
- **Infrastructure as Code:** Terraform >= 1.10.0 (Modular architecture, S3 native state locking)
- **Orchestration:** Amazon EKS (Kubernetes 1.37)
- **Continuous Integration:** GitHub Actions (ESLint, Node tests, Trivy vulnerability scanning)
- **Continuous Delivery:** GitHub Actions + AWS OIDC Authentication + Automated Rollback
- **Security:** Kubernetes Restricted Pod Security Standards, NetworkPolicies, Non-Root UID 1000
- **Observability:** Prometheus, Grafana, AWS CloudWatch Logs & Metrics

---

## 📜 License

MIT
