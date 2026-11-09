#!/usr/bin/env bash
set -euo pipefail

# Automated Kind deployment script with health checks and rollback support
# Usage: ./scripts/deploy-kind.sh <sha-40char-commit-hash>

IMAGE_TAG="${1:-}"

if [[ -z "$IMAGE_TAG" ]] || [[ ! "$IMAGE_TAG" =~ ^sha-[a-f0-9]{40}$ ]]; then
    echo "Usage: $0 <sha-40char-commit-hash>"
    echo "Example: $0 sha-6fcbeaa636d66d3e234fc54f0e9c490751610b71"
    exit 1
fi

EXPECTED_CONTEXT="kind-todo-lab"
NAMESPACE="todo-app"
BACKEND_DEPLOYMENT="backend"
FRONTEND_DEPLOYMENT="frontend"

BACKEND_IMAGE="pratik0207/todolist-backend:${IMAGE_TAG}"
FRONTEND_IMAGE="pratik0207/todolist-frontend:${IMAGE_TAG}"

HEALTH_URL="http://localhost:8080/health"
READY_URL="http://localhost:8080/ready"

ORIGINAL_BACKEND_IMAGE=""
ORIGINAL_FRONTEND_IMAGE=""
BACKEND_UPDATE_STARTED=false
FRONTEND_UPDATE_STARTED=false

write_step() {
    echo -e "\n\033[1;36m==> $1\033[0m"
}

write_success() {
    echo -e "\033[1;32m[SUCCESS] $1\033[0m"
}

write_error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m" >&2
}

rollback() {
    write_step "Initiating rollback"
    if [[ "$BACKEND_UPDATE_STARTED" == true ]] && [[ -n "$ORIGINAL_BACKEND_IMAGE" ]]; then
        echo "Rolling back backend to $ORIGINAL_BACKEND_IMAGE"
        kubectl set image deployment/"$BACKEND_DEPLOYMENT" backend="$ORIGINAL_BACKEND_IMAGE" -n "$NAMESPACE" || true
        kubectl rollout status deployment/"$BACKEND_DEPLOYMENT" -n "$NAMESPACE" --timeout=120s || true
    fi
    if [[ "$FRONTEND_UPDATE_STARTED" == true ]] && [[ -n "$ORIGINAL_FRONTEND_IMAGE" ]]; then
        echo "Rolling back frontend to $ORIGINAL_FRONTEND_IMAGE"
        kubectl set image deployment/"$FRONTEND_DEPLOYMENT" frontend="$ORIGINAL_FRONTEND_IMAGE" -n "$NAMESPACE" || true
        kubectl rollout status deployment/"$FRONTEND_DEPLOYMENT" -n "$NAMESPACE" --timeout=120s || true
    fi
    write_error "Rollback completed. Exiting with failure."
    exit 1
}

trap 'rollback' ERR

# 1. Verify Docker Hub images
write_step "Verifying container images"
docker manifest inspect "$BACKEND_IMAGE" > /dev/null
write_success "Backend image is available"

docker manifest inspect "$FRONTEND_IMAGE" > /dev/null
write_success "Frontend image is available"

# 2. Verify Kubernetes context
write_step "Checking Kubernetes context"
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != "$EXPECTED_CONTEXT" ]]; then
    write_error "Wrong Kubernetes context: $CURRENT_CONTEXT. Expected: $EXPECTED_CONTEXT"
    exit 1
fi
write_success "Connected to $EXPECTED_CONTEXT"

# 3. Verify cluster connectivity & namespace
write_step "Checking cluster connectivity and namespace"
kubectl cluster-info > /dev/null
kubectl get namespace "$NAMESPACE" > /dev/null
write_success "Cluster reachable and namespace $NAMESPACE exists"

# 4. Capture current deployment images
write_step "Capturing current deployment images for rollback"
ORIGINAL_BACKEND_IMAGE=$(kubectl get deployment "$BACKEND_DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
ORIGINAL_FRONTEND_IMAGE=$(kubectl get deployment "$FRONTEND_DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "Current backend:  $ORIGINAL_BACKEND_IMAGE"
echo "Current frontend: $ORIGINAL_FRONTEND_IMAGE"

# 5. Update backend
if [[ "$ORIGINAL_BACKEND_IMAGE" == "$BACKEND_IMAGE" ]]; then
    write_success "Backend already on target image. Skipping."
else
    write_step "Updating backend image to $BACKEND_IMAGE"
    BACKEND_UPDATE_STARTED=true
    kubectl set image deployment/"$BACKEND_DEPLOYMENT" backend="$BACKEND_IMAGE" -n "$NAMESPACE"
    kubectl rollout status deployment/"$BACKEND_DEPLOYMENT" -n "$NAMESPACE" --timeout=180s
    write_success "Backend rollout completed"
fi

# 6. Update frontend
if [[ "$ORIGINAL_FRONTEND_IMAGE" == "$FRONTEND_IMAGE" ]]; then
    write_success "Frontend already on target image. Skipping."
else
    write_step "Updating frontend image to $FRONTEND_IMAGE"
    FRONTEND_UPDATE_STARTED=true
    kubectl set image deployment/"$FRONTEND_DEPLOYMENT" frontend="$FRONTEND_IMAGE" -n "$NAMESPACE"
    kubectl rollout status deployment/"$FRONTEND_DEPLOYMENT" -n "$NAMESPACE" --timeout=180s
    write_success "Frontend rollout completed"
fi

# 7. Verify application health
write_step "Checking application health"
MAX_ATTEMPTS=6
HEALTHY=false

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    echo "Health check attempt $i/$MAX_ATTEMPTS..."
    if curl -sf --max-time 10 "$HEALTH_URL" > /dev/null && curl -sf --max-time 10 "$READY_URL" > /dev/null; then
        HEALTHY=true
        break
    fi
    sleep 5
done

if [[ "$HEALTHY" != true ]]; then
    write_error "Application health checks failed after $MAX_ATTEMPTS attempts"
    rollback
fi

write_success "Application health checks passed"

# 8. Summary
write_step "Deployment summary"
kubectl get deployments -n "$NAMESPACE"
write_success "Kind deployment completed successfully"
