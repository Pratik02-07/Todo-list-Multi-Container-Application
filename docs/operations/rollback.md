# Application Deployment & Rollback Runbook

This runbook establishes procedures for initiating fast, zero-downtime rollbacks when a new release introduces regressions, crashes, or severe latency.

---

## 1. Automated Pipeline Rollback

The Continuous Deployment workflow ([`.github/workflows/cd.yml`](../../.github/workflows/cd.yml)) automatically evaluates rollout health:
- Waits up to 300 seconds for pod readiness.
- If pods fail readiness or enter `CrashLoopBackOff`, the workflow intercepts the failure and executes:
  ```bash
  kubectl rollout undo deployment/backend -n todo-app
  kubectl rollout undo deployment/frontend -n todo-app
  ```
- Reverts workloads immediately to the previous known-good replica set.

---

## 2. Manual Operator Rollback

### Step 1: Check Rollout History
Inspect previous revision numbers and change causes:
```bash
kubectl rollout history deployment/backend -n todo-app
kubectl rollout history deployment/frontend -n todo-app
```

### Step 2: Instant Rollback to Previous Revision
Roll back both application tiers to the immediately preceding revision:
```bash
# Rollback backend
kubectl rollout undo deployment/backend -n todo-app

# Rollback frontend
kubectl rollout undo deployment/frontend -n todo-app
```

### Step 3: Rollback to a Specific Historic Revision
If rolling back multiple releases:
```bash
kubectl rollout undo deployment/backend -n todo-app --to-revision=<REVISION_NUMBER>
kubectl rollout undo deployment/frontend -n todo-app --to-revision=<REVISION_NUMBER>
```

### Step 4: Monitor Rollout Completion
```bash
kubectl rollout status deployment/backend -n todo-app --timeout=180s
kubectl rollout status deployment/frontend -n todo-app --timeout=180s
```

### Step 5: Verify Application Health
```bash
# Verify pod statuses
kubectl get pods -n todo-app -o wide

# Test API health
curl -f http://<ALB_DNS_NAME>/health
curl -f http://<ALB_DNS_NAME>/ready
```
