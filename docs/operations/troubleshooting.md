# EKS & Application Troubleshooting Guide

This guide provides diagnostic procedures and resolution steps for common failure modes encountered across the **Todo List Multi-Container Application** platform.

---

## 1. Quick Diagnostic Cheat-Sheet

```bash
# 1. Cluster nodes overview
kubectl get nodes -o wide

# 2. Application pod statuses
kubectl get pods -n todo-app -o wide

# 3. Pod events and failure descriptions
kubectl describe pod <POD_NAME> -n todo-app

# 4. Tail application logs
kubectl logs -f deployment/backend -n todo-app
kubectl logs -f deployment/frontend -n todo-app

# 5. Ingress & Load Balancer status
kubectl get ingress todo-app -n todo-app
kubectl describe ingress todo-app -n todo-app
```

---

## 2. Common Failure Modes & Resolutions

### A. Pod in `CrashLoopBackOff`
- **Cause 1: Missing Environment Variable / Invalid URI**
  - Check logs: `kubectl logs <POD_NAME> -n todo-app`
  - Look for: `Invalid environment variables: ...` from Zod validation in `utils/env.js`.
  - Fix: Check `configmap.yaml` and `todo-app-secret`.
- **Cause 2: MongoDB Connection Failure**
  - Look for: `Failed to connect to MongoDB on startup`.
  - Fix: Verify MongoDB pod is running (`kubectl get pods -l app=mongodb -n todo-app`) and Service `mongodb` resolves.

### B. Pod in `Pending` State
- **Cause 1: Insufficient Node Resources**
  - Run `kubectl describe pod <POD_NAME> -n todo-app`.
  - Look for: `0/2 nodes are available: 2 Insufficient cpu/memory`.
  - Fix: Scale node group via Terraform or adjust resource requests in `backend.yaml`/`frontend.yaml`.
- **Cause 2: PVC Not Bound (MongoDB)**
  - Look for: `waiting for a volume to be created, either by dynamic provisioning or manual creation`.
  - Fix: Verify AWS EBS CSI Driver add-on is active and `ebs-gp3` StorageClass exists.

### C. HTTP 502 / 504 Bad Gateway from Application Load Balancer
- **Cause 1: Ingress Target Group Unhealthy**
  - Check ALB target group health in AWS Console or AWS CLI.
  - Fix: Confirm the `/ready` probe responds with HTTP 200 on backend pods.
- **Cause 2: NetworkPolicy Blocking Traffic**
  - Confirm `allow-frontend` NetworkPolicy permits port 80 ingress from ALB.

### D. Terraform Remote State Locked
- **Error:** `Error acquiring the state lock ... Lock Info: ...`
- **Resolution:**
  - Verify no apply process is currently active.
  - Release lock using: `terraform force-unlock <LOCK_ID>`.
  - If using S3 native locking, delete stale `.tflock` file in S3:
    ```bash
    aws s3 rm "s3://<STATE_BUCKET>/dev/terraform.tfstate.tflock"
    ```
