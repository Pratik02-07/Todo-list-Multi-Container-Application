# 📦 Todo App Helm Chart

A production-ready Helm chart to deploy the Multi-Container Todo List application (Frontend, Express Backend, MongoDB) onto Kubernetes and Amazon EKS.

---

## 🏗️ Architecture in Kubernetes

```
                      AWS Application Load Balancer (ALB)
                                      │
                                      ▼
                      ┌───────────────────────────────┐
                      │ Frontend Service (ClusterIP)  │
                      └──────────────┬────────────────┘
                                     │
                     ┌───────────────┴───────────────┐
                     ▼                               ▼
             Frontend Pod (Zone A)           Frontend Pod (Zone B)
                     │                               │
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                      ┌───────────────────────────────┐
                      │  Backend Service (ClusterIP)  │
                      └──────────────┬────────────────┘
                                     │
                     ┌───────────────┴───────────────┐
                     ▼                               ▼
             Backend Pod (Zone A)            Backend Pod (Zone B)
                     │                               │
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                      ┌───────────────────────────────┐
                      │ MongoDB Service (Headless)    │
                      └──────────────┬────────────────┘
                                     │
                                     ▼
                      ┌───────────────────────────────┐
                      │ MongoDB Pod (StatefulSet)     │
                      │  └── PVC: 10Gi (ebs-gp3)      │
                      └───────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Install the Chart (Default Production Values)

```bash
helm upgrade --install todo-app ./helm/todo-app \
  --namespace todo-app \
  --create-namespace
```

### 2. Install for Development (`values-dev.yaml`)

```bash
helm upgrade --install todo-app ./helm/todo-app \
  --namespace todo-app \
  --create-namespace \
  -f ./helm/todo-app/values-dev.yaml
```

### 3. Continuous Deployment (CI/CD Automated Image Updates)

In your CI/CD pipeline, you **never need to edit YAML files** when pushing new container images. Use the `--set` flag to dynamically inject newly built image tags at deploy time:

```bash
# Option A: Update BOTH frontend and backend simultaneously using the Git commit SHA:
helm upgrade --install todo-app ./helm/todo-app \
  --namespace todo-app \
  --set global.image.tag="sha-${GITHUB_SHA}"

# Option B: Update individual service tags independently:
helm upgrade --install todo-app ./helm/todo-app \
  --namespace todo-app \
  --set frontend.image.tag="sha-${GITHUB_SHA}" \
  --set backend.image.tag="sha-${GITHUB_SHA}"
```

Kubernetes detects the tag change (e.g. `...:old-sha` -> `...:new-sha`) and executes an automated, zero-downtime rolling update.

### 4. Check Rollout & Pods

```bash
kubectl get pods,svc,pvc,ingress -n todo-app -o wide
```

### 5. Access the Application

Retrieve the public Application Load Balancer address:
```bash
kubectl get ingress -n todo-app
```
Open the generated `http://k8s-todoapp-...elb.amazonaws.com` address in your browser.

---

## 🔄 Automated CI/CD Workflow Integration (GitHub Actions)

Here is how to automate image deployments in your GitHub Actions workflow (`.github/workflows/deploy.yml` or `ci.yml`). After building and pushing Docker images to Docker Hub, deploy them automatically to EKS with Helm:

```yaml
- name: Deploy new images to EKS with Helm
  run: |
    # 1. Update kubeconfig context for Amazon EKS
    aws eks update-kubeconfig --region ap-south-1 --name todo-app-eks-dev

    # 2. Deploy or upgrade with the new Git commit SHA tag
    helm upgrade --install todo-app ./helm/todo-app \
      --namespace todo-app \
      --create-namespace \
      --set global.image.tag="sha-${{ github.sha }}"

    # 3. Wait for zero-downtime rolling updates to finish
    kubectl rollout status deployment/todo-app-backend -n todo-app --timeout=3m
    kubectl rollout status deployment/todo-app-frontend -n todo-app --timeout=3m
```

### Why Helm for Automated Deployments:
- **Zero File Edits**: Image tags are passed as CLI parameters; no git commits needed just to bump image versions.
- **Atomic Rollouts**: Helm tracks release revisions (`revision 1`, `revision 2`, etc.).
- **One-Command Rollback**: If a bad image fails health probes or encounters errors, roll back immediately:
  ```bash
  # Check revision history:
  helm history todo-app -n todo-app

  # Roll back to the previous healthy revision:
  helm rollback todo-app -n todo-app
  ```

---

## ⚙️ Configuration Parameters

### Global & Common
| Parameter | Description | Default |
|---|---|---|
| `global.environment` | Target environment label | `"production"` |
| `global.image.tag` | Global image tag overriding both frontend & backend simultaneously (ideal for CI/CD) | `""` |

### Frontend
| Parameter | Description | Default |
|---|---|---|
| `frontend.replicaCount` | Replicas for the UI | `2` |
| `frontend.image.repository` | Image repository | `pratik0207/todolist-frontend` |
| `frontend.image.tag` | Immutable image tag | `sha-6fcbeaa6...` |
| `frontend.service.type` | Kubernetes service type | `ClusterIP` |
| `frontend.service.port` | Service port | `80` |
| `frontend.pdb.enabled` | PodDisruptionBudget enabled | `true` |
| `frontend.pdb.minAvailable` | Minimum available pods | `1` |
| `frontend.topologySpreadConstraints.enabled` | Multi-AZ scheduling constraints | `true` |

### Backend
| Parameter | Description | Default |
|---|---|---|
| `backend.replicaCount` | Replicas for the Express API | `2` |
| `backend.image.repository` | Image repository | `pratik0207/todolist-backend` |
| `backend.image.tag` | Immutable image tag | `sha-6fcbeaa6...` |
| `backend.service.port` | Service port | `3000` |
| `backend.env.nodeEnv` | Node.js environment | `"production"` |
| `backend.pdb.enabled` | PodDisruptionBudget enabled | `true` |
| `backend.topologySpreadConstraints.enabled` | Multi-AZ scheduling constraints | `true` |

### MongoDB
| Parameter | Description | Default |
|---|---|---|
| `mongodb.enabled` | Deploy in-cluster MongoDB StatefulSet | `true` |
| `mongodb.image.tag` | MongoDB image tag | `"7.0"` |
| `mongodb.database` | Database name | `"tododb"` |
| `mongodb.auth.rootUsername` | Root admin username | `"todo_admin"` |
| `mongodb.auth.rootPassword` | Root admin password | `"ChangeMeInProduction123!"` |
| `mongodb.persistence.enabled` | Enable PVC persistence | `true` |
| `mongodb.persistence.storageClass` | StorageClass name | `"ebs-gp3"` |
| `mongodb.persistence.size` | Storage volume size | `10Gi` |

### Ingress & StorageClass
| Parameter | Description | Default |
|---|---|---|
| `ingress.enabled` | Enable AWS ALB Ingress | `true` |
| `ingress.className` | IngressClass | `"alb"` |
| `storageClass.create` | Create AWS EBS gp3 StorageClass | `true` |
| `storageClass.name` | StorageClass name | `"ebs-gp3"` |

---

## 🧹 Uninstall

```bash
helm uninstall todo-app -n todo-app
```
