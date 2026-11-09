# DevSecOps & Security Hardening Architecture

This document describes the security controls, policies, vulnerability management, and secret handling implemented across the **Todo List Multi-Container Application** on Amazon EKS.

---

## 1. Threat Model & Defense-in-Depth Strategy

```
Layer                  Security Controls
─────────────────────────────────────────────────────────────────────────────
CI/CD Pipeline         Trivy (FS/Image), Checkov (IaC), npm audit, Git OIDC
Cloud (AWS)            IAM least privilege, IRSA boundaries, S3 TLS enforcement
Network                VPC private subnets, Security Groups, Kubernetes NetworkPolicies
Compute (EKS)          Restricted Pod Security Standards, non-root containers
Storage                EBS gp3 KMS encryption, S3 AES256 server-side encryption
Secrets                AWS Secrets Manager / sealed Kubernetes secrets
```

---

## 2. Workload & Container Hardening

### Non-Root Execution
All application containers run as unprivileged users:
- **Backend:** Executes as `appuser:appgroup` (UID `1000`, GID `1000`).
- **Kubernetes Security Context:**
  ```yaml
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
    - name: backend
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
  ```

### Image Vulnerability Scanning
- **Trivy Scanner:** Automated in CI ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)) and on schedule ([`.github/workflows/security.yml`](../../.github/workflows/security.yml)).
- Evaluates OS packages and npm production dependencies, blocking `CRITICAL` and `HIGH` severity CVEs.

---

## 3. Secret Management Architecture

### Current Implementation
- Application credentials (`mongo-root-username`, `mongo-root-password`, `mongo-uri`) are decoupled from container images and configuration maps into Kubernetes `Secret` objects.
- Environment variables are injected into pods using `secretKeyRef`.

### Production Integration: AWS Secrets Manager
For production enterprise environments, the recommended pattern is integrating **External Secrets Operator (ESO)** with AWS Secrets Manager:

1. Store credentials in AWS Secrets Manager:
   ```bash
   aws secretsmanager create-secret \
     --name "todo-app/prod/mongodb" \
     --secret-string '{"username":"todo_admin","password":"<STRONG_PASSWORD>"}'
   ```
2. Provision an IAM IRSA role granting `secretsmanager:GetSecretValue`.
3. Deploy an `ExternalSecret` manifest mapping the AWS secret directly to a Kubernetes `todo-app-secret`.

---

## 4. Network Microsegmentation (NetworkPolicies)

The application namespace enforces strict traffic isolation via Kubernetes `NetworkPolicy` objects:
- **Frontend:** Ingress permitted on port 80 from AWS ALB.
- **Backend:** Ingress on port 3000 permitted **only** from pods matching `app: frontend`.
- **MongoDB:** Ingress on port 27017 permitted **only** from pods matching `app: backend`.
- All unauthorized lateral pod communication is rejected by default.

---

## 5. Infrastructure Security (IaC)

- **Terraform Checkov Analysis:** Scans all Terraform modules for CIS AWS benchmarks, IAM wildcard permissions, and unencrypted volumes.
- **S3 State Security:**
  - AES256 Server-Side Encryption.
  - S3 Versioning enabled.
  - S3 Public Access Block fully enabled.
  - S3 Bucket Policy enforcing TLS (`aws:SecureTransport: "false"` denial).
