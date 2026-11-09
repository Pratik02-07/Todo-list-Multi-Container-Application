#!/usr/bin/env bash
set -euo pipefail

# Build Docker images locally for backend and frontend
TAG="${1:-local}"

echo "=========================================="
echo " Building Todo Application Docker Images"
echo " Tag: ${TAG}"
echo "=========================================="

echo "--> Building Backend Image (todo-backend:${TAG})..."
docker build \
  --file backend/Dockerfile \
  --tag "todo-backend:${TAG}" \
  .

echo "--> Building Frontend Image (todo-frontend:${TAG})..."
docker build \
  --file frontend/Dockerfile \
  --tag "todo-frontend:${TAG}" \
  .

echo "=========================================="
echo " Images built successfully:"
docker images | grep -E "todo-backend|todo-frontend" || true
echo "=========================================="
