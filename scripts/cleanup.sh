#!/usr/bin/env bash
set -euo pipefail

# Clean up Todo List application resources from EKS
NAMESPACE="todo-app"

echo "=========================================="
echo " Cleaning Up Todo Application from EKS"
echo " Namespace: ${NAMESPACE}"
echo "=========================================="

echo "--> Deleting application resources via Kustomize..."
kubectl delete -k k8s/overlays/eks --ignore-not-found=true

echo "=========================================="
echo " Remaining resources in ${NAMESPACE} (PVCs / Secrets):"
kubectl get pvc,secret -n "${NAMESPACE}" --no-headers 2>/dev/null || echo "No resources remaining."
echo " Note: PVCs are preserved to protect database data."
echo " Run 'kubectl delete namespace ${NAMESPACE}' for total teardown."
echo "=========================================="
