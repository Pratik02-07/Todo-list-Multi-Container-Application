# Contributing & Engineering Standards

This document defines the branching strategy, commit conventions, code quality gates, and deployment workflows for the **Todo List — Multi-Container Application** project.

---

## 🌿 Git Branching Strategy

| Branch | Purpose | Protection Rules |
|---|---|---|
| `main` | Production-ready source of truth. Deployed to EKS dev/staging environments. | Requires passing PR checks (lint, tests, Kustomize validation). Direct pushes restricted. |
| `feature/*` | Feature development and improvements (e.g. `feature/phase1-backend-improvements`). | PR opened against `main`. Automated CI validates tests on every push. |
| `fix/*` | Bug fixes and patches (e.g. `fix/db-reconnect-handling`). | PR opened against `main`. |

---

## 💬 Commit Message Convention

This project strictly adheres to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <short description>
```

### Common Types:
- `feat`: A new feature (e.g., `feat(backend): add graceful shutdown handlers`)
- `fix`: A bug fix (e.g., `fix(k8s): resolve ingress health check path`)
- `docs`: Documentation updates (e.g., `docs: update root README with architecture diagram`)
- `refactor`: Code refactoring without behavioral changes (e.g., `refactor(k8s): standardize base image names`)
- `test`: Adding or updating tests (e.g., `test(api): add CRUD integration tests`)
- `ci`: CI/CD workflow modifications (e.g., `ci: add automated Trivy container scan`)
- `chore`: Maintenance tasks and dependency updates (e.g., `chore: update .dockerignore`)

---

## 🛡️ Pre-PR Quality Gates

Before opening a Pull Request, ensure all local checks pass cleanly:

```bash
# 1. Run unit tests
npm test

# 2. Run code style & linting
npm run lint

# 3. Verify Terraform syntax and formatting
terraform fmt -check -recursive terraform/

# 4. Validate Kubernetes Kustomize overlays
kubectl kustomize k8s/overlays/eks > /dev/null
```

---

## 🏷️ Docker Image Tagging Strategy

- **Local Development**: `todo-backend:local` and `todo-frontend:local`.
- **CI/CD Push to Registry**: Immutable Git commit SHA tags:
  ```
  todo-backend:sha-<commit-sha>
  todo-frontend:sha-<commit-sha>
  ```
- **Semantic Version Releases**: Triggered by git tags (`vMAJOR.MINOR.PATCH`):
  ```
  todo-backend:v1.0.0
  todo-frontend:v1.0.0
  ```
- **Rule**: `latest` is never used as the deployment source of truth in Kubernetes manifests.
