# Sub-Project 2: Blue-Green Deployment Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a production-grade Blue-Green deployment architecture with zero-downtime traffic switching in Nginx, pre-cutover container health checks, automated resource conservation, and sub-second rollback.

**Architecture:** `docker-compose.yml` orchestrates dual Node.js application containers (`app_blue` and `app_green`) connected to `todo_network` and sharing `mongo_data`. Nginx reads its upstream from a dynamically mounted file `nginx/upstream.conf`. A cross-platform Node.js automation script (`scripts/deploy-blue-green.js`) provisions the idle candidate, asserts internal health, gracefully flips Nginx upstream with `nginx -s reload`, stops the previous container, and provides immediate rollback via `--rollback`.

**Tech Stack:** Docker Compose, Nginx (Alpine), Node.js (automation & verification), Bash, PowerShell.

**Spec:** `docs/superpowers/specs/2026-11-03-subproject-2-blue-green-deployment-design.md`

## Global Constraints
- Work directly in the repository on main (user instructed no branching).
- Port 80 on host must remain the only public entrypoint via Nginx.
- Nginx upstream must be dynamically loaded from `/etc/nginx/conf.d/upstream.conf`.
- Deployment must verify candidate health BEFORE switching traffic.
- Rollback must restore the previous container in <3 seconds without downtime.
- All 26 automated unit and integration tests (`npm test`) must continue to pass.

---

### Task 1: Configure Dual-Service Blue/Green in Docker Compose and Dynamic Upstream in Nginx

**Files:**
- Create: `nginx/upstream.conf`
- Modify: `nginx/nginx.conf`
- Modify: `docker-compose.yml`

**Interfaces:**
- Produces: Dual application services `app_blue` and `app_green` in Docker Compose and dynamic upstream loading in Nginx.

- [ ] **Step 1: Create `nginx/upstream.conf`**

Create `nginx/upstream.conf`:
```nginx
server app_blue:3000;
```

- [ ] **Step 2: Update `nginx/nginx.conf` to include `upstream.conf`**

Modify `nginx/nginx.conf`:
```nginx
upstream app {
    include /etc/nginx/conf.d/upstream.conf;
    keepalive 16;
}

server {
    listen 80;
    server_name _;

    client_max_body_size 1m;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Serve static frontend
    location / {
        root   /usr/share/nginx/html;
        index  index.html;
        try_files $uri $uri/ /index.html;
    }

    # Proxy API endpoints
    location /api {
        proxy_pass         http://app;
        proxy_http_version 1.1;
        proxy_set_header   Connection "";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }

    # Proxy Health endpoint
    location /health {
        proxy_pass         http://app;
        proxy_http_version 1.1;
        proxy_set_header   Connection "";
        proxy_set_header   Host $host;
    }
}
```

- [ ] **Step 3: Update `docker-compose.yml` with `app_blue`, `app_green`, and `upstream.conf` volume**

Modify `docker-compose.yml`:
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

  # ── Nginx Reverse Proxy & Static Host ────────────────────────────────────────
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

# ── Named Volumes ────────────────────────────────────────────────────────────
volumes:
  mongo_data:
    driver: local

# ── Networks ─────────────────────────────────────────────────────────────────
networks:
  todo_network:
    driver: bridge
```

- [ ] **Step 4: Launch compose stack with `app_blue` and `nginx`**

Run:
```bash
docker compose up -d --remove-orphans app_blue nginx mongo
```
Verify `docker compose ps` shows `todo_app_blue`, `todo_mongo`, and `todo_nginx` running.
Verify `curl -s http://localhost/health` returns `{ "status": "ok", "version": "1.0.0", "color": "blue" }`.

- [ ] **Step 5: Commit Task 1**

```bash
git add nginx/upstream.conf nginx/nginx.conf docker-compose.yml
git commit -m "feat: configure dual-service Blue/Green in Docker Compose and dynamic Nginx upstream"
```

---

### Task 2: Implement Automated Blue-Green Deployment & Rollback Script

**Files:**
- Create: `scripts/deploy-blue-green.js`
- Create: `scripts/deploy-blue-green.sh`
- Create: `scripts/deploy-blue-green.ps1`

**Interfaces:**
- Produces: Executable deployment and rollback automation CLI.

- [ ] **Step 1: Implement `scripts/deploy-blue-green.js`**

Create `scripts/deploy-blue-green.js`:
```javascript
#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const http = require('http');

const ROOT_DIR = path.resolve(__dirname, '..');
const UPSTREAM_FILE = path.join(ROOT_DIR, 'nginx', 'upstream.conf');

function run(cmd, options = {}) {
  return execSync(cmd, { cwd: ROOT_DIR, stdio: 'pipe', encoding: 'utf-8', ...options }).trim();
}

function runInteractive(cmd) {
  execSync(cmd, { cwd: ROOT_DIR, stdio: 'inherit' });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function checkLiveHealth() {
  return new Promise((resolve) => {
    http.get('http://127.0.0.1/health', (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
}

function getCurrentActiveColor() {
  if (fs.existsSync(UPSTREAM_FILE)) {
    const content = fs.readFileSync(UPSTREAM_FILE, 'utf-8');
    if (content.includes('app_green:3000')) return 'green';
    if (content.includes('app_blue:3000')) return 'blue';
  }
  return 'blue';
}

async function waitForContainerHealth(containerName, expectedColor, timeoutSec = 30) {
  const startTime = Date.now();
  process.stdout.write(`   Waiting for container ${containerName} to be healthy...`);

  while (Date.now() - startTime < timeoutSec * 1000) {
    try {
      const output = run(`docker exec ${containerName} wget -qO- http://127.0.0.1:3000/health`);
      const parsed = JSON.parse(output);
      if (parsed.status === 'ok' && (!expectedColor || parsed.color === expectedColor)) {
        console.log(' [HEALTHY]');
        return true;
      }
    } catch {}
    await sleep(1500);
    process.stdout.write('.');
  }

  console.log(' [TIMEOUT]');
  return false;
}

function reloadNginx() {
  run('docker exec todo_nginx nginx -s reload');
}

function switchUpstream(targetColor) {
  const content = `server app_${targetColor}:3000;\n`;
  fs.writeFileSync(UPSTREAM_FILE, content, 'utf-8');
  reloadNginx();
}

async function rollback() {
  console.log('\n======================================================');
  console.log(' Triggering Instant Blue-Green Rollback               ');
  console.log('======================================================\n');

  const activeColor = getCurrentActiveColor();
  const previousColor = activeColor === 'blue' ? 'green' : 'blue';
  const previousContainer = `todo_app_${previousColor}`;

  console.log(`1. Current active color: [${activeColor.toUpperCase()}]`);
  console.log(`2. Starting previous container: ${previousContainer}...`);
  try {
    runInteractive(`docker compose start app_${previousColor}`);
  } catch (err) {
    console.error(`Failed to start ${previousContainer}:`, err.message);
    process.exit(1);
  }

  const healthy = await waitForContainerHealth(previousContainer, previousColor, 15);
  if (!healthy) {
    console.error(`ERROR: Previous container ${previousContainer} failed health check!`);
    process.exit(1);
  }

  console.log(`3. Switching Nginx traffic back to [${previousColor.toUpperCase()}]...`);
  switchUpstream(previousColor);

  console.log(`4. Stopping [${activeColor.toUpperCase()}] container...`);
  try {
    run(`docker compose stop app_${activeColor}`);
  } catch {}

  console.log('\n======================================================');
  console.log(` ROLLBACK SUCCESSFUL! Now serving: [${previousColor.toUpperCase()}] `);
  console.log('======================================================\n');
}

async function deploy(newVersion) {
  const activeColor = getCurrentActiveColor();
  const targetColor = activeColor === 'blue' ? 'green' : 'blue';
  const targetContainer = `todo_app_${targetColor}`;
  const envVarName = targetColor === 'blue' ? 'BLUE_VERSION' : 'GREEN_VERSION';

  console.log('\n======================================================');
  console.log(` Starting Blue-Green Deployment: [${activeColor.toUpperCase()}] -> [${targetColor.toUpperCase()}] `);
  console.log(` Target Version: ${newVersion}`);
  console.log('======================================================\n');

  console.log(`1. Provisioning idle candidate container: ${targetContainer}...`);
  const env = { ...process.env, [envVarName]: newVersion };
  try {
    runInteractive(`docker compose up -d --no-deps --build app_${targetColor}`, { env });
  } catch (err) {
    console.error(`Failed to build/start candidate container:`, err.message);
    process.exit(1);
  }

  console.log(`2. Verifying candidate container health prior to traffic cutover...`);
  const healthy = await waitForContainerHealth(targetContainer, targetColor, 30);

  if (!healthy) {
    console.error(`\n[ABORT] Health check failed for ${targetContainer}!`);
    console.error(`Active container [${activeColor.toUpperCase()}] was left untouched. Stopping candidate...`);
    try {
      run(`docker compose stop app_${targetColor}`);
    } catch {}
    process.exit(1);
  }

  console.log(`3. Performing zero-downtime traffic cutover to [${targetColor.toUpperCase()}]...`);
  switchUpstream(targetColor);

  // Verify external Nginx proxy
  console.log(`4. Verifying proxy response from Nginx...`);
  let verified = false;
  for (let i = 0; i < 10; i++) {
    const health = await checkLiveHealth();
    if (health && health.color === targetColor) {
      verified = true;
      console.log(`   Live Nginx response confirmed: version=${health.version}, color=${health.color}`);
      break;
    }
    await sleep(500);
  }

  if (!verified) {
    console.error(`[WARNING] Nginx reload succeeded but health endpoint did not reflect target color.`);
  }

  console.log(`5. Draining and stopping previous container (app_${activeColor})...`);
  try {
    run(`docker compose stop app_${activeColor}`);
  } catch (err) {
    console.log(`   Note: Could not stop previous container: ${err.message}`);
  }

  console.log('\n======================================================');
  console.log(` DEPLOYMENT SUCCESSFUL! Now serving: [${targetColor.toUpperCase()}] v${newVersion} `);
  console.log('======================================================\n');
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--rollback')) {
    await rollback();
    return;
  }

  let version = '2.0.0';
  const versionIdx = args.indexOf('--version');
  if (versionIdx !== -1 && args[versionIdx + 1]) {
    version = args[versionIdx + 1];
  }

  await deploy(version);
}

main().catch((err) => {
  console.error('Deployment execution failed:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Create Bash wrapper `scripts/deploy-blue-green.sh`**

Create `scripts/deploy-blue-green.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "$DIR/deploy-blue-green.js" "$@"
```

- [ ] **Step 3: Create PowerShell wrapper `scripts/deploy-blue-green.ps1`**

Create `scripts/deploy-blue-green.ps1`:
```powershell
param (
    [string]$Version = "2.0.0",
    [switch]$Rollback
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Rollback) {
    node "$ScriptDir\deploy-blue-green.js" --rollback
} else {
    node "$ScriptDir\deploy-blue-green.js" --version $Version
}
```

- [ ] **Step 4: Commit Task 2**

```bash
git add scripts/deploy-blue-green.js scripts/deploy-blue-green.sh scripts/deploy-blue-green.ps1
git commit -m "feat: implement automated Blue-Green deployment and instant rollback scripts"
```

---

### Task 3: Implement Zero-Downtime Traffic Verification Test Script and Execute Live Soak Test

**Files:**
- Create: `scripts/verify-zero-downtime.js`
- Modify: `README.md`

**Interfaces:**
- Produces: Executable soak test verifying 0 dropped requests during live deployment and rollback.

- [ ] **Step 1: Create `scripts/verify-zero-downtime.js`**

Create `scripts/verify-zero-downtime.js`:
```javascript
#!/usr/bin/env node
const http = require('http');
const { spawn } = require('child_process');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');
const DEPLOY_SCRIPT = path.join(ROOT_DIR, 'scripts', 'deploy-blue-green.js');

let totalRequests = 0;
let successRequests = 0;
let failedRequests = 0;
const colorCounts = { blue: 0, green: 0, other: 0 };
let keepSending = true;

function sendProbe() {
  return new Promise((resolve) => {
    totalRequests++;
    const req = http.get('http://127.0.0.1/health', (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        if (res.statusCode === 200) {
          successRequests++;
          try {
            const parsed = JSON.parse(data);
            const color = parsed.color || 'other';
            colorCounts[color] = (colorCounts[color] || 0) + 1;
          } catch {
            colorCounts.other++;
          }
        } else {
          failedRequests++;
        }
        resolve();
      });
    });

    req.on('error', () => {
      failedRequests++;
      resolve();
    });

    req.setTimeout(2000, () => {
      req.destroy();
      failedRequests++;
      resolve();
    });
  });
}

async function generateContinuousTraffic(ratePerSec = 25) {
  while (keepSending) {
    sendProbe();
    await new Promise((r) => setTimeout(r, 1000 / ratePerSec));
  }
}

function runDeploy(args = []) {
  return new Promise((resolve, reject) => {
    console.log(`\n>> Triggering: node scripts/deploy-blue-green.js ${args.join(' ')}`);
    const proc = spawn('node', [DEPLOY_SCRIPT, ...args], { cwd: ROOT_DIR, stdio: 'inherit' });
    proc.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`Deployment exited with code ${code}`));
    });
  });
}

async function runTest() {
  console.log('==========================================================');
  console.log(' Starting Zero-Downtime Blue-Green Verification Soak Test ');
  console.log('==========================================================\n');

  // Start continuous probe generation in background
  generateContinuousTraffic(30);

  // Let initial traffic establish
  console.log('Step 1: Generating baseline traffic for 3 seconds...');
  await new Promise((r) => setTimeout(r, 3000));
  console.log(`   Baseline sent: ${totalRequests} requests, ${failedRequests} failed.`);

  // Trigger deployment: switch to v2.0.0
  console.log('\nStep 2: Triggering live Blue-Green deployment to v2.0.0...');
  await runDeploy(['--version', '2.0.0']);

  // Allow post-deploy traffic to run
  console.log('\nStep 3: Sampling post-deployment traffic for 3 seconds...');
  await new Promise((r) => setTimeout(r, 3000));

  // Trigger rollback: switch back
  console.log('\nStep 4: Triggering live Blue-Green rollback...');
  await runDeploy(['--rollback']);

  // Allow post-rollback traffic to run
  console.log('\nStep 5: Sampling post-rollback traffic for 3 seconds...');
  await new Promise((r) => setTimeout(r, 3000));

  // Stop traffic generator
  keepSending = false;
  await new Promise((r) => setTimeout(r, 1000));

  console.log('\n==========================================================');
  console.log(' ZERO-DOWNTIME SOAK TEST RESULTS                          ');
  console.log('==========================================================');
  console.log(`Total Requests Sent : ${totalRequests}`);
  console.log(`Successful (200 OK) : ${successRequests}`);
  console.log(`Failed / Dropped    : ${failedRequests}`);
  console.log(`Requests by Color   : Blue = ${colorCounts.blue}, Green = ${colorCounts.green}`);

  if (failedRequests > 0) {
    console.error(`\n[TEST FAILED] Encountered ${failedRequests} dropped requests during deployment!`);
    process.exit(1);
  }

  if (colorCounts.blue === 0 || colorCounts.green === 0) {
    console.error('\n[TEST FAILED] Did not observe traffic to both Blue and Green containers.');
    process.exit(1);
  }

  console.log('\n[PASS] Verified 100% Zero-Downtime Deployment & Instant Rollback!');
  console.log('==========================================================\n');
}

runTest().catch((err) => {
  keepSending = false;
  console.error('\nTest error:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Update `README.md` with Blue-Green architecture and commands**

Add Blue-Green section to `README.md` detailing:
- Topology (`app_blue`, `app_green`, `upstream.conf`)
- Deploying new version: `node scripts/deploy-blue-green.js --version 2.0.0`
- Instant rollback: `node scripts/deploy-blue-green.js --rollback`
- Running zero-downtime test: `node scripts/verify-zero-downtime.js`

- [ ] **Step 3: Execute `node scripts/verify-zero-downtime.js` live**

Run:
```bash
node scripts/verify-zero-downtime.js
```
Expected:
- Total requests sent > 250
- Failed / Dropped = 0
- Both Blue and Green requests captured
- Output concludes with `[PASS] Verified 100% Zero-Downtime Deployment & Instant Rollback!`

- [ ] **Step 4: Commit Task 3**

```bash
git add scripts/verify-zero-downtime.js README.md
git commit -m "test: implement and verify automated zero-downtime Blue-Green deployment soak test"
```
