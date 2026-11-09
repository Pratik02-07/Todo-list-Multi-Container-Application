# CI/CD Pipeline & Delivery Automation

This document details the continuous integration, continuous delivery, and DevSecOps pipelines implemented using **GitHub Actions**, **Amazon ECR / Docker Hub**, and **Amazon EKS**.

---

## 1. End-to-End Pipeline Workflow

```
Developer Push / PR
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ GitHub Actions CI (ci.yml)                                  │
│  - npm ci                                                   │
│  - npm test (Unit & Integration Tests)                      │
│  - npm run lint (ESLint)                                    │
│  - kubectl kustomize validate                               │
│  - Trivy Container & Filesystem Vulnerability Scan          │
└──────────────────────────┬──────────────────────────────────┘
                           │ (On Push to main / Release Tag)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Build & Publish Images (Docker Buildx)                      │
│  - todo-backend:sha-<commit>                                │
│  - todo-frontend:sha-<commit>                               │
└──────────────────────────┬──────────────────────────────────┘
                           │ (Workflow Run / Dispatch)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ GitHub Actions CD (cd.yml)                                  │
│  - Authenticate to AWS via OIDC                             │
│  - aws eks update-kubeconfig                                │
│  - kustomize edit set image todo-backend=sha-<commit>       │
│  - kubectl apply -k k8s/overlays/eks                        │
│  - Monitor rollout status (--timeout=300s)                  │
│  - Health smoke checks                                      │
│  - Automated Rollback on failure (kubectl rollout undo)     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. GitHub Actions Authentication via AWS OIDC

To follow AWS least privilege and eliminate long-lived AWS IAM access keys stored as GitHub secrets, the CD workflow authenticates via **OpenID Connect (OIDC)**:

### IAM Trust Policy (AWS Deployer Role)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::570934197541:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:pratik0207/todo-list-multi-container:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

---

## 3. Automated Rollback & Recovery Strategy

If an updated image introduces a regression:
1. `kubectl rollout status` monitors pod readiness.
2. If the rollout times out or pods enter `CrashLoopBackOff`, the step fails.
3. The `failure()` conditional step executes immediately:
   ```bash
   kubectl rollout undo deployment/backend -n todo-app
   kubectl rollout undo deployment/frontend -n todo-app
   ```
4. Pods return to the prior working image tag with zero user-facing downtime.
