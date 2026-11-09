#!/usr/bin/env bash
set -euo pipefail

# Run test suites, code quality checks, and manifest validations locally

echo "=========================================="
echo " 1. Running Unit & Integration Tests"
echo "=========================================="
npm test

echo "=========================================="
echo " 2. Running ESLint Code Quality Checks"
echo "=========================================="
npm run lint

echo "=========================================="
echo " 3. Auditing Production Dependencies"
echo "=========================================="
npm audit --omit=dev

echo "=========================================="
echo " 4. Validating Kubernetes Manifests (EKS)"
echo "=========================================="
kubectl kustomize k8s/overlays/eks > /dev/null

echo "=========================================="
echo " 5. Checking Terraform Formatting"
echo "=========================================="
terraform fmt -check -recursive terraform/

echo "=========================================="
echo " All Quality & Validation Gates Passed!"
echo "=========================================="
