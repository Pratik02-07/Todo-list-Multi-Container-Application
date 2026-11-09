#!/usr/bin/env bash
set -euo pipefail

# Deploy Todo List application to Amazon EKS overlay
NAMESPACE="todo-app"

echo "=========================================="
echo " Deploying Todo Application to EKS"
echo " Namespace: ${NAMESPACE}"
echo "=========================================="

echo "--> Checking kubectl connectivity..."
kubectl cluster-info > /dev/null

echo "--> Applying EKS Kustomize overlay..."
kubectl apply -k k8s/overlays/eks

echo "--> Monitoring Backend rollout..."
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=300s

echo "--> Monitoring Frontend rollout..."
kubectl rollout status deployment/frontend -n "${NAMESPACE}" --timeout=300s

echo "=========================================="
echo " Deployment Summary in ${NAMESPACE}:"
kubectl get deployments,services,ingress,hpa,pvc -n "${NAMESPACE}"
echo "=========================================="
