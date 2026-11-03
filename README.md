# 📝 Todo List — Multi-Container Application

> A production-ready REST API built with **Node.js**, **Express**, and **MongoDB**, served through **Nginx** as a reverse proxy with **Let's Encrypt SSL/HTTPS** — orchestrated with **Docker Compose**, provisioned on **AWS EC2** via **Terraform** (including **Route 53 DNS & CNAME**), configured with **Ansible**, and deployed automatically through **GitHub Actions**.
>
> Project reference: [roadmap.sh/projects/multi-container-service](https://roadmap.sh/projects/multi-container-service)

---

## 🏗️ Architecture

```
                  ┌────────────────────────────────────────────────────────┐
                  │                 AWS & Docker Network                   │
  Client ──443──▶ │  Route 53 (CNAME) ──▶ Nginx (:80/:443 SSL)            │
  (HTTPS)         │                         │                              │
                  │                         ├──/api──▶ Node.js (:3000)     │
                  │                                         │              │
                  │                                         └──▶ MongoDB   │
                  │                                              (:27017)  │
                  └────────────────────────────────────────────────────────┘
```

| Container | Image | Role |
|-----------|-------|------|
| `todo_nginx` | `nginx:1.27-alpine` | Reverse proxy on ports 80 & 443 with Let's Encrypt SSL |
| `todo_app` | Custom (Dockerfile) | Express REST API on port 3000 |
| `todo_mongo` | `mongo:7.0` | Persistent MongoDB database (named volume) |

---

## 📁 Project Structure

```
Todo-list-Multi-Container/
│
├── src/
│   ├── config/
│   │   └── db.js               # MongoDB connection
│   ├── models/
│   │   └── Todo.js             # Mongoose schema
│   ├── routes/
│   │   └── todoRoutes.js       # Express router
│   ├── controllers/
│   │   └── todoController.js   # CRUD business logic
│   └── server.js               # App entry point
│
├── nginx/
│   ├── nginx.conf              # Local development config (HTTP 80)
│   └── nginx.prod.conf         # Production config (HTTP 80 redirect + HTTPS 443 SSL)
│
├── infrastructure/
│   ├── terraform/
│   │   ├── main.tf             # EC2 + Security Group (80, 443, 22) + Route 53 Zone & CNAME
│   │   ├── variables.tf        # AWS region, domain_name, subdomain, etc.
│   │   └── outputs.tf          # Public IP, Route 53 Name Servers, CNAME FQDN, HTTPS URL
│   └── ansible/
│       ├── playbook.yml        # Docker, Certbot SSL, Nginx HTTPS deploy, auto-renewal cron
│       └── inventory.ini       # EC2 host (fill in after terraform apply)
│
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD: lint → build/push → Ansible deploy
│
├── Dockerfile                  # Multi-stage production image
├── docker-compose.yml          # Local orchestration
├── .dockerignore
├── .env.example                # Environment variable template
└── README.md
```

---

## 🌐 Adding CNAME in get.tech (`todo.pratikpatil.tech`)

This project is configured for **Option 1**: adding the CNAME directly in **get.tech**, keeping your main website `http://pratikpatil.tech/` active and completely untouched.

### Step 1 — Provision Infrastructure with Terraform

```bash
cd infrastructure/terraform

terraform init
terraform apply \
  -var="key_name=your-ec2-keypair" \
  -var="dockerhub_image=yourusername/todo-app:latest"
```

From the outputs, take note of:
- `public_ip`: used for your Ansible inventory.
- `public_dns`: the EC2 DNS target for get.tech (e.g. `ec2-xx-xx-xx-xx.compute-1.amazonaws.com`).

### Step 2 — Add CNAME Record in get.tech Control Panel

1. Log in to [get.tech / Radix control panel](https://manage.tech.host).
2. Go to **Domain Registration** → **Manage Orders** → select **`pratikpatil.tech`**.
3. Under **DNS Management**, click **Manage DNS**.
4. Click **Add CNAME Record**:
   - **Host Name**: `todo`
   - **Type**: `CNAME`
   - **Value**: `<paste your EC2 public_dns>`
   - **TTL**: `300` (or `7200`)
5. Click **Save**.

### Step 3 — Deploy & Issue SSL with Ansible

Add the `public_ip` to `infrastructure/ansible/inventory.ini`, then run:

```bash
cd infrastructure/ansible

ansible-playbook -i inventory.ini playbook.yml
```

The playbook will:
1. Deploy the multi-container stack (`app`, `mongo`, `nginx`).
2. Run Certbot to verify domain ownership via HTTP-01 challenge on `todo.pratikpatil.tech`.
3. Issue and install an official Let's Encrypt SSL certificate.
4. Reload Nginx and configure auto-renewal cron.
5. Your API will be live at: **`https://todo.pratikpatil.tech/api/todos`**.


---

## 🔒 Automated Let's Encrypt SSL with Ansible

The included Ansible playbook handles the complete SSL bootstrap:
1. Installs `docker`, `docker-compose-plugin`, `certbot`, and `openssl`.
2. Generates a temporary bootstrap self-signed certificate so Nginx can start immediately.
3. Starts the production multi-container stack with port 80 & 443 exposed.
4. Solves the Let's Encrypt HTTP-01 challenge using Certbot's webroot plugin (`/var/www/certbot`).
5. Overwrites the bootstrap cert with the authentic Let's Encrypt SSL certificate.
6. Gracefully reloads Nginx to serve live HTTPS traffic.
7. Installs a daily cron job that auto-renews certificates and reloads Nginx.

### Running Ansible Manually:

```bash
cd infrastructure/ansible

# 1. Add your EC2 public IP to inventory.ini
nano inventory.ini

# 2. Run playbook with your domain & email
DOCKERHUB_IMAGE=yourusername/todo-app:latest \
CERT_DOMAIN=todo.yourdomain.com \
CERT_EMAIL=you@yourdomain.com \
ansible-playbook -i inventory.ini playbook.yml
```

---

## 🚀 Quick Start (Local Development)

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with Docker Compose v2+

### 1. Clone & configure

```bash
cp .env.example .env
```

### 2. Build and run

```bash
docker compose up --build -d
```

### 3. Verify

```bash
# Check containers
docker compose ps

# Test API
curl http://localhost/api/todos
# Output: {"success":true,"count":0,"data":[]}
```

### 4. Stop

```bash
docker compose down            # keeps mongo volume
docker compose down -v         # also clears data volume
```

---

## 🌐 API Reference

Base URL (Local): `http://localhost/api`  
Base URL (Production HTTPS): `https://todo.yourdomain.com/api`

| Method | Endpoint | Description | Body |
|--------|----------|-------------|------|
| `GET` | `/todos` | List all todos | — |
| `GET` | `/todos/:id` | Get a single todo | — |
| `POST` | `/todos` | Create a todo | `{ "title": "...", "description": "..." }` |
| `PUT` | `/todos/:id` | Update a todo | `{ "title": "...", "completed": true }` |
| `DELETE` | `/todos/:id` | Delete a todo | — |
| `GET` | `/health` | Health check | — |

---

## 🔄 CI/CD Pipeline (GitHub Actions)

On every push to `main`:
1. **Lint**: ESLint runs on Node.js source files.
2. **Build & Push**: Docker Buildx creates the multi-stage image and pushes tags (`latest` & commit SHA) to Docker Hub.
3. **Deploy**: Sets up Python & Ansible, writes SSH key, injects domain & secrets, and triggers Ansible playbook on EC2.

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `EC2_HOST` | EC2 public IP (from `terraform output public_ip`) |
| `EC2_SSH_PRIVATE_KEY` | Contents of your EC2 `.pem` private key |
| `CERT_DOMAIN` | Your CNAME domain (e.g. `todo.yourdomain.com`) |
| `CERT_EMAIL` | Contact email for Let's Encrypt expiration notifications |

---

## 📜 License

MIT
