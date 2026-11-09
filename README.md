# 📝 Todo List — End-to-End AWS EKS DevOps Multi-Container Platform

> A production-grade, portfolio-ready DevOps project showcasing a full-stack multi-container application deployed on **Amazon EKS (Elastic Kubernetes Service)** using **Terraform**, **Docker**, **Kubernetes (Kustomize)**, and **GitHub Actions CI/CD**.
>
> Grounded in the [roadmap.sh Multi-Container Service](https://roadmap.sh/projects/multi-container-service) specification and expanded into an end-to-end cloud-native delivery pipeline.

---

## 🏗️ Architecture Overview

The platform is designed with clear separation of concerns across presentation, application logic, persistence, infrastructure, and delivery pipelines.

### High-Level Topology

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
└────────────┬─────────────┘  │  - Health Probes (/health,    │
             │                │    /ready, /health/startup)   │
             │                └──────────────┬────────────────┘
             └───────────────────────────────┤
                                             ▼ (:27017)
                              ┌───────────────────────────────┐
                              │ MongoDB Database (StatefulSet)│
                              │  - Dedicated Headless Service │
                              │  - AWS EBS gp3 Persistent Vol │
                              └───────────────────────────────┘
```

### Components

| Component | Technology | Role |
|---|---|---|
| **Frontend** | Nginx 1.27 + HTML/CSS/JS | Reverse proxy on port 80, static web host for dark-mode UI, security headers |
| **Backend** | Node.js 22 + Express + Mongoose | REST API on port 3000 with Zod schema validation, structured error handling |
| **Database** | MongoDB 7.0 | Persistent NoSQL database configured as Kubernetes StatefulSet with EBS gp3 storage |
| **Containerization** | Docker & Docker Compose | Multi-stage Dockerfiles (non-root), local multi-container development |
| **Orchestration** | Kubernetes & Kustomize | Base manifests and EKS overlay (Deployments, Services, PDB, TopologySpreadConstraints, Ingress) |
| **Infrastructure as Code** | Terraform (>= 1.10) | Modular AWS provisioning: VPC, IAM, EKS, Add-ons (VPC-CNI, CoreDNS, Kube-Proxy, EBS CSI), AWS Load Balancer Controller |
| **State Management** | Amazon S3 Native Locking | Encrypted, versioned S3 bucket leveraging Terraform native S3 state locking (`use_lockfile = true`) |
| **CI/CD Automation** | GitHub Actions | Automated linting, tests, container builds, security scans, and EKS deployments |

---

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci.yml                 # Test, lint, build, scan & publish container images
│       └── tf.yml                 # Terraform format, validation & OIDC plan
├── backend/
│   ├── Dockerfile                 # Multi-stage production Node.js build (non-root)
│   └── src/
│       ├── config/db.js           # Mongoose connection & lifecycle handling
│       ├── controllers/           # Todo CRUD business logic
│       ├── middlewares/           # Centralized error handler & Zod validation
│       ├── models/Todo.js         # Mongoose schema definition
│       ├── routes/todoRoutes.js   # Express API route declarations
│       ├── utils/AppError.js      # Operational error class
│       ├── validators/            # Zod validation schemas
│       └── server.js              # Express entry point & health endpoints
├── frontend/
│   ├── Dockerfile                 # Nginx-based frontend container
│   ├── nginx/nginx.conf           # Reverse proxy, caching & security headers
│   └── public/                    # Static Web UI (HTML5, modern CSS, vanilla JS)
├── k8s/
│   ├── base/                      # Base Kubernetes resources
│   │   ├── backend.yaml           # Backend Deployment & ClusterIP Service
│   │   ├── frontend.yaml          # Frontend Deployment & Service
│   │   ├── mongodb.yaml           # MongoDB StatefulSet & Headless Service
│   │   └── kustomization.yaml     # Base Kustomize manifest
│   └── overlays/
│       └── eks/                   # Amazon EKS overlay
│           ├── configmap.yaml     # Environment configuration
│           ├── ingress.yaml       # AWS ALB Ingress configuration
│           ├── storageclass.yaml  # EBS gp3 StorageClass (EBS CSI driver)
│           ├── *-pdb.yaml         # PodDisruptionBudgets
│           ├── *-topology.*.yaml  # Multi-AZ topology spread constraints
│           └── kustomization.yaml # EKS Kustomize configuration
├── terraform/
│   ├── bootstrap/
│   │   └── state-backend/         # S3 remote state bucket with native locking
│   ├── environments/
│   │   └── dev/                   # Dev environment orchestration & provider setup
│   └── modules/
│       ├── networking/            # VPC, public/private subnets, NAT GW, ELB tags
│       ├── iam/                   # Cluster, Node, and IRSA IAM roles
│       ├── eks/                   # EKS cluster, Spot node group, OIDC
│       ├── addons/                # VPC-CNI, CoreDNS, kube-proxy, EBS CSI driver
│       └── controllers/           # AWS Load Balancer Controller (Helm + IRSA)
├── scripts/
│   ├── deploy-kind.ps1            # Local Kind cluster automated deployment (PowerShell)
│   └── deploy-kind.sh             # Local Kind cluster automated deployment (Bash)
├── tests/
│   └── todoValidator.test.js      # Unit tests for request validation schemas
├── kind/
│   └── kind-config.yaml           # Multi-node Kind cluster definition
├── docker-compose.yml             # Local multi-container orchestration
├── eslint.config.js               # ESLint 9+ flat configuration
├── package.json                   # Root scripts and dependencies
└── README.md
```

---

## 🚀 Quick Start (Local Development)

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with Compose v2+
- Node.js >= 22 (for local development and testing)

### 1. Environment Configuration
```bash
cp .env.example .env
```

### 2. Run with Docker Compose
```bash
docker compose up --build -d
```

### 3. Verify Local Services
```bash
# Verify container health
docker compose ps

# Web UI: Open http://localhost in browser
# Health check:
curl http://localhost/health

# Readiness check (confirms MongoDB connectivity):
curl http://localhost/ready

# API endpoint:
curl http://localhost/api/todos
```

### 4. Stop Services
```bash
docker compose down        # Preserves database volume
docker compose down -v     # Cleans up database volume
```

---

## 🧪 Testing & Code Quality

Run tests and linting using the native Node.js test runner and ESLint:

```bash
# Run unit tests
npm test

# Run code linter
npm run lint

# Audit production dependencies
npm audit --omit=dev
```

---

## ☸️ Local Kubernetes Testing (Kind)

To test the application manifests locally before provisioning AWS infrastructure:

```bash
# 1. Create a Kind cluster with port mapping
kind create cluster --name kind-todo-lab --config kind/kind-config.yaml

# 2. Deploy the application with automated health checks and rollback:
# On Linux/macOS:
./scripts/deploy-kind.sh <image-tag>

# On Windows (PowerShell):
./scripts/deploy-kind.ps1 -ImageTag <image-tag>
```

---

## ☁️ AWS Infrastructure Deployment (Terraform)

### 1. Bootstrap Remote S3 State Backend
```bash
cd terraform/bootstrap/state-backend
terraform init
terraform apply
```
*Note: Uses S3 native state locking (`use_lockfile = true`) — no DynamoDB table required.*

### 2. Deploy Development Environment
```bash
cd ../../environments/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Configure Local `kubectl`
```bash
$(terraform output -raw configure_kubectl)
kubectl get nodes -o wide
```

### 4. Deploy Application to EKS
```bash
# Deploy namespace, storage class, and application overlay
kubectl apply -k k8s/overlays/eks
kubectl rollout status deployment/backend -n todo-app --timeout=5m
kubectl rollout status deployment/frontend -n todo-app --timeout=5m
```

---

## 🌐 API Reference

Base URL: `http://localhost` (or ALB DNS in AWS)

| Method | Endpoint | Description | Request Body |
|---|---|---|---|
| `GET` | `/` | Web UI (served by Nginx) | — |
| `GET` | `/health` | Liveness probe (process responsive) | — |
| `GET` | `/health/startup` | Startup probe (database initialized) | — |
| `GET` | `/ready` | Readiness probe (database connected) | — |
| `GET` | `/api/todos` | List all todos | — |
| `GET` | `/api/todos/:id` | Get single todo by ID | — |
| `POST` | `/api/todos` | Create a new todo | `{ "title": "string", "description": "string" }` |
| `PUT` | `/api/todos/:id` | Update a todo | `{ "title": "string", "completed": boolean }` |
| `DELETE` | `/api/todos/:id` | Delete a todo | — |

---

## 📜 License

MIT
