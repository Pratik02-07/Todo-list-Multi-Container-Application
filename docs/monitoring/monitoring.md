# Observability, Monitoring & Alerting Guide

This document details the telemetry, log aggregation, metric collection, and alerting architecture for the **Todo List Multi-Container Application** deployed on Amazon EKS.

---

## 1. Observability Stack Architecture

```
Telemetry Source         Scraper / Collector            Visualization & Storage
─────────────────────────────────────────────────────────────────────────────
Kubernetes Metrics    ──▶ Metrics Server / Prometheus ──▶ Grafana Dashboards
Application Health    ──▶ /health, /ready, /startup   ──▶ Prometheus & ALB Checks
Pod / Cluster Logs    ──▶ Fluent Bit / AWS DaemonSet  ──▶ Amazon CloudWatch Logs
Control Plane Logs    ──▶ AWS EKS Audit & API logs    ──▶ CloudWatch Log Groups
```

---

## 2. Key Telemetry Indicators (SLIs)

### Application Telemetry (Express & Nginx)
- **Availability:** Rate of successful 2xx/3xx HTTP responses vs. 5xx responses.
- **Latency:** Request duration across `GET /api/todos`, `POST /api/todos`, `PUT /api/todos/:id`.
- **Throughput:** Requests per second (RPS) routed through the AWS Application Load Balancer.
- **Health Probes:**
  - `GET /health`: Liveness probe (process responsiveness).
  - `GET /health/startup`: Startup probe (initial DB connection verification).
  - `GET /ready`: Readiness probe (live MongoDB connection status).

### Cluster & Node Telemetry (EKS & EC2)
- **Node Utilization:** Spot instance CPU and Memory allocation vs. capacity.
- **Pod Lifecycle:** Pod restarts (`CrashLoopBackOff`), pending pods, CPU/Memory throttling.
- **Storage Metrics:** EBS gp3 PersistentVolumeClaim volume space and IOPS consumption.

---

## 3. Recommended Prometheus & Grafana Configuration

### Prometheus Operator ServiceMonitor
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: todo-backend-monitor
  namespace: todo-app
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
    - port: http
      path: /health
      interval: 15s
```

### Core Grafana Dashboards
1. **Kubernetes Compute Resources:** Pods, Deployments, and StatefulSets CPU & Memory utilization against defined requests and limits.
2. **Ingress & Traffic:** ALB incoming request rates, target response time, and HTTP status code distribution.
3. **Database Health:** Active MongoDB connections, operation latency, and write queue depths.

---

## 4. Operational Alerting Rules

| Alert Name | Severity | Condition | Action |
|---|:---:|---|---|
| `BackendDown` | Critical | `sum(up{app="backend"}) == 0` for 2m | Trigger PagerDuty/Slack; inspect pod logs |
| `High5xxErrorRate` | Critical | HTTP 5xx responses > 5% for 5m | Inspect API logs and MongoDB connectivity |
| `DatabaseDisconnected` | Critical | `/ready` probe returning 503 for 1m | Verify MongoDB StatefulSet and PVC health |
| `PodCrashLooping` | Warning | Rate of pod restarts > 2 per 5m | Check container logs (`kubectl logs -n todo-app`) |
| `PVCNearingCapacity` | Warning | Volume usage > 85% | Expand EBS volume size in StorageClass / PVC |
