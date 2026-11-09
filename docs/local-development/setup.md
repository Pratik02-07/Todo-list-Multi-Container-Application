# Local Development & Testing Guide

This guide walks through spinning up, testing, and debugging the **Todo List Multi-Container Application** locally using **Docker Compose** and **Kind (Kubernetes in Docker)**.

---

## 1. Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (v24+ with Compose v2)
- [Node.js](https://nodejs.org/) (v22 LTS recommended)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.30+)
- [Kind](https://kind.sigs.k8s.io/) (v0.22+ for local Kubernetes testing)

---

## 2. Docker Compose Environment

The local Docker Compose environment mirrors the multi-container architecture without requiring cloud infrastructure:

### Start All Services
```bash
# 1. Initialize environment file
cp .env.example .env

# 2. Build and launch containers in detached mode
docker compose up --build -d
```

### Inspect Container Health
```bash
docker compose ps
```
Expected output:
- `backend`: Healthy (port 3000)
- `frontend`: Healthy (port 80)
- `mongo`: Healthy (port 27017)

### Test Local Endpoints
```bash
# Web UI
curl -I http://localhost/

# Health & Readiness
curl http://localhost/health
curl http://localhost/ready

# Todo REST API
curl -X POST http://localhost/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test task","description":"Testing local environment"}'
```

### Stop Services
```bash
docker compose down        # Retains MongoDB persistent volume
docker compose down -v     # Deletes MongoDB volume for fresh restart
```

---

## 3. Local Kubernetes Testing (Kind)

Kind simulates a multi-node Kubernetes cluster on your local Docker daemon.

### 1. Create Kind Cluster
```bash
kind create cluster --name kind-todo-lab --config kind/kind-config.yaml
```

### 2. Deploy Application via Script
```bash
# On Linux / macOS
./scripts/deploy-kind.sh <image-tag>

# On Windows (PowerShell)
./scripts/deploy-kind.ps1 -ImageTag <image-tag>
```

### 3. Verify Local Kind Pods
```bash
kubectl get pods,svc -n todo-app -o wide
```
Open `http://localhost:8080` in your browser.
