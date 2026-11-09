# Kubernetes Workload Deployment Guide

This document describes the Kubernetes application architecture and Kustomize overlays used to run the **Todo List Multi-Container Application** on Amazon EKS.

---

## 1. Kustomize Architecture

```
k8s/
├── base/                              # Environment-agnostic definitions
│   ├── backend.yaml                   # Express Deployment & Service
│   ├── frontend.yaml                  # Nginx Deployment & NodePort Service
│   ├── mongodb.yaml                   # MongoDB StatefulSet & Headless Service
│   └── kustomization.yaml
└── overlays/
    └── eks/                           # Amazon EKS specific customization
        ├── namespace.yaml             # Dedicated todo-app namespace
        ├── configmap.yaml             # Application configuration
        ├── storageclass.yaml          # ebs-gp3 StorageClass definition
        ├── ingress.yaml               # AWS ALB Ingress with SSL redirect
        ├── frontend-service.patch.yaml# Patches Frontend Service to ClusterIP
        ├── frontend-pdb.yaml          # PodDisruptionBudget (minAvailable: 1)
        ├── backend-pdb.yaml           # PodDisruptionBudget (minAvailable: 1)
        ├── frontend-topology.patch.yaml # Multi-AZ topology spread constraints
        ├── backend-topology.patch.yaml  # Multi-AZ topology spread constraints
        ├── mongodb-storage.patch.yaml # Volume claim template using ebs-gp3
        ├── hpa.yaml                   # HorizontalPodAutoscalers for frontend/backend
        ├── networkpolicy.yaml         # Pod microsegmentation NetworkPolicies
        ├── mongodb-backup-cronjob.yaml# Daily S3 database backup CronJob
        └── kustomization.yaml
```

---

## 2. Workload Specifications

### A. Backend API (`backend.yaml`)
- **Type:** Deployment (2 replicas default, autoscaling 2–6 via HPA).
- **Service:** ClusterIP on port 3000.
- **Security Context:** `runAsNonRoot: true`, `runAsUser: 1000`, `allowPrivilegeEscalation: false`, drop `ALL` capabilities.
- **Probes:**
  - `startupProbe`: `GET /health/startup` (5s interval, 30 failures threshold).
  - `readinessProbe`: `GET /ready` (5s interval, verifies MongoDB connection).
  - `livenessProbe`: `GET /health` (10s interval, verifies process response).
- **Resources:** Requests: 100m CPU / 128Mi RAM; Limits: 500m CPU / 512Mi RAM.

### B. Frontend (`frontend.yaml`)
- **Type:** Deployment (2 replicas default, autoscaling 2–6 via HPA).
- **Service:** ClusterIP on port 80 (patched by EKS overlay for ALB routing).
- **Probes:** `GET /ready` and `GET /health`.
- **Resources:** Requests: 50m CPU / 64Mi RAM; Limits: 250m CPU / 128Mi RAM.

### C. MongoDB (`mongodb.yaml`)
- **Type:** StatefulSet (1 replica, single-node learning setup).
- **Service:** Headless ClusterIP (`None`) on port 27017.
- **Storage:** 8Gi EBS gp3 volume dynamically provisioned via `ebs-gp3` StorageClass.
- **Probes:** Readiness and liveness via `mongosh --eval "db.adminCommand('ping').ok"`.

---

## 3. High Availability & Resilience Features

- **PodDisruptionBudgets:** Configured with `minAvailable: 1` so worker node drainage during Spot terminations never takes both backend or frontend replicas offline simultaneously.
- **Topology Spread Constraints:** Ensures pods are balanced across both AWS Availability Zones (`ap-south-1a` and `ap-south-1b`) and worker node hostnames (`maxSkew: 1`).
- **NetworkPolicies:** Restricts cross-namespace and pod-to-pod communications so only frontend can reach backend, and only backend can reach MongoDB.
