# Design Specification: Sub-Project 2 — Blue-Green Zero-Downtime Deployment Architecture

## 1. Overview
Sub-Project 2 establishes a production-grade **Blue-Green Deployment Architecture** for the Multi-Container Todo Application. The goal is to deploy new versions of the application container without downtime, with zero dropped requests, and with immediate automated rollback capabilities.

Key deliverables:
1. **Dual Application Services in Docker Compose**: Configuring explicit `app_blue` and `app_green` services in `docker-compose.yml`, both connected to the internal bridge network `todo_network` and sharing the persistent database `mongo_data`.
2. **Dynamic Upstream Switching in Nginx**: Nginx dynamically delegates upstream routing to `nginx/upstream.conf`. Traffic cutover occurs via graceful reload (`nginx -s reload`), maintaining in-flight connections on old workers while immediately serving new requests from the newly deployed container.
3. **Automated Cross-Platform Deployment Script (`scripts/deploy-blue-green.js`)**: Orchestrates candidate container provisioning, pre-cutover health check gating, dynamic upstream rewrite, Nginx graceful reload, old container resource management, and instant rollback (`--rollback`).
4. **Zero-Downtime Verification Suite (`scripts/verify-zero-downtime.js`)**: Simulates continuous client traffic during live deployment and asserts zero failed requests and seamless color/version transition.

---

## 2. Container Topology & Networking

```
                     ┌────────────────────────────────────────────────────────┐
                     │                 Docker Network: todo_network           │
                     │                                                        │
Client Browser ──▶  │  Nginx Reverse Proxy (:80)                             │
                     │  (container: todo_nginx)                               │
                     │                         │                              │
                     │                         ▼ [includes upstream.conf]     │
                     │                  ┌──────────────┐                      │
                     │                  │ upstream app │                      │
                     │                  └──────┬───────┘                      │
                     │                         │                              │
                     │        [Active Traffic] │ [Standby / Deployment]       │
                     │        ┌────────────────┴────────────────┐             │
                     │        ▼                                 ▼             │
                     │  ┌───────────────┐                 ┌───────────────┐   │
                     │  │   app_blue    │                 │   app_green   │   │
                     │  │  (:3000 priv) │                 │  (:3000 priv) │   │
                     │  │ [v1.0.0 Blue] │                 │ [v2.0.0 Green]│   │
                     │  └───────┬───────┘                 └───────┬───────┘   │
                     │          │                                 │           │
                     │          └────────────────┬────────────────┘           │
                     │                           │ (shared connection)        │
                     │                           ▼                            │
                     │                    ┌──────────────┐                    │
                     │                    │  todo_mongo  │                    │
                     │                    │  (:27017)    │                    │
                     │                    │  mongo_data  │                    │
                     │                    └──────────────┘                    │
                     └────────────────────────────────────────────────────────┘
```

### Network & Port Isolation
- Only `todo_nginx` publishes port `80:80` to the host.
- Neither `app_blue` nor `app_green` publish host ports; they communicate over `todo_network` via DNS names `app_blue` and `app_green` on port 3000.
- `todo_mongo` communicates exclusively on `todo_network:27017` with volume `mongo_data`.

---

## 3. Docker Compose & Nginx Configuration

### 3.1 `docker-compose.yml` Dual-Service Layout
```yaml
services:
  # ── Blue Application Container ──────────────────────────────────────────────
  app_blue:
    image: pratik0207/todolist-app:latest
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: todo_app_blue
    restart: unless-stopped
    env_file: .env
    environment:
      - NODE_ENV=production
      - MONGO_URI=mongodb://mongo:27017/tododb
      - APP_VERSION=${BLUE_VERSION:-1.0.0}
      - APP_COLOR=blue
    depends_on:
      mongo:
        condition: service_healthy
    networks:
      - todo_network

  # ── Green Application Container ─────────────────────────────────────────────
  app_green:
    image: pratik0207/todolist-app:latest
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: todo_app_green
    restart: unless-stopped
    env_file: .env
    environment:
      - NODE_ENV=production
      - MONGO_URI=mongodb://mongo:27017/tododb
      - APP_VERSION=${GREEN_VERSION:-1.0.0}
      - APP_COLOR=green
    depends_on:
      mongo:
        condition: service_healthy
    networks:
      - todo_network

  # ── MongoDB Database ────────────────────────────────────────────────────────
  mongo:
    image: mongo:7.0
    container_name: todo_mongo
    restart: unless-stopped
    volumes:
      - mongo_data:/data/db
    networks:
      - todo_network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s

  # ── Nginx Reverse Proxy ─────────────────────────────────────────────────────
  nginx:
    image: nginx:1.27-alpine
    container_name: todo_nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx/upstream.conf:/etc/nginx/conf.d/upstream.conf:ro
      - ./public:/usr/share/nginx/html:ro
    depends_on:
      - app_blue
    networks:
      - todo_network

volumes:
  mongo_data:
    driver: local

networks:
  todo_network:
    driver: bridge
```

### 3.2 Dynamic Upstream (`nginx/upstream.conf` and `nginx/nginx.conf`)
- `nginx/upstream.conf`:
  ```nginx
  server app_blue:3000;
  ```
- `nginx/nginx.conf`:
  ```nginx
  upstream app {
      include /etc/nginx/conf.d/upstream.conf;
      keepalive 16;
  }
  ```

---

## 4. Deployment Automation & Rollback Specification

### 4.1 Deployment Script (`scripts/deploy-blue-green.js`)
Executable via CLI:
```bash
node scripts/deploy-blue-green.js [--version <version>] [--color <blue|green>] [--rollback]
```

#### Step-by-Step Execution Sequence:
1. **State Discovery**:
   - Reads `nginx/upstream.conf` or queries `http://localhost/health`.
   - Determines active target (`current`) and idle target (`candidate`).
   - For regular deployment: if active is `blue`, candidate is `green` (and vice versa).
2. **Pre-Deployment Candidate Start**:
   - Sets environment variables (e.g. `GREEN_VERSION=2.0.0`).
   - Runs `docker compose up -d --no-deps --build app_<candidate>`.
3. **Candidate Health Check Gate (Pre-Cutover Safety)**:
   - Polls `docker exec todo_app_<candidate> wget -qO- http://127.0.0.1:3000/health`.
   - Polling interval: 1.5 seconds; timeout: 30 seconds.
   - Asserts response HTTP status is 200, `"status":"ok"`, and `"color":"<candidate>"`.
   - **Abort on Failure**: If health checks fail within 30 seconds:
     - Stop candidate container: `docker compose stop app_<candidate>`.
     - Log failure diagnostics and exit code 1.
     - Active container remains completely untouched with 0 impact to running users.
4. **Traffic Cutover**:
   - Rewrites `nginx/upstream.conf` on host to `server app_<candidate>:3000;`.
   - Sends graceful reload signal: `docker exec todo_nginx nginx -s reload`.
   - Verifies external response: queries `http://localhost/health` to confirm active color and version match the candidate.
5. **Drain & Resource Conservation**:
   - Once traffic switch is confirmed, gracefully stops previous container: `docker compose stop app_<current>`.
   - Previous container remains intact on disk, allowing sub-second rollback.

### 4.2 Automated Rollback (`--rollback`)
1. Detects current active color (e.g. `green`).
2. Identifies rollback target (`blue`).
3. Starts previous container: `docker compose start app_blue`.
4. Polls health check until `app_blue` is healthy.
5. Rewrites `nginx/upstream.conf` to `server app_blue:3000;`.
6. Executes `docker exec todo_nginx nginx -s reload`.
7. Stops `app_green`.
8. Execution completes in <3 seconds with zero downtime.

---

## 5. Zero-Downtime Verification & Traffic Soak Test

### 5.1 Verification Script (`scripts/verify-zero-downtime.js`)
- Continuously sends requests to `http://localhost/health` and `http://localhost/api/todos` at 20 requests per second across 15 seconds.
- Spawns child process running `node scripts/deploy-blue-green.js --version 2.0.0`.
- Collects metrics:
  - Total requests sent.
  - Successful requests (HTTP 200).
  - Failed requests (HTTP != 200 or network drops).
  - Transition point timestamp (when color switches from blue to green).
- **Pass Criteria**:
  - `failedRequests === 0`.
  - Both `blue` and `green` responses recorded.
  - No connection drops or timeouts during `nginx -s reload`.
- Tests `--rollback` under load to verify reverse switchover with zero failures.
