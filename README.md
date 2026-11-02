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

## 🌐 Custom Domain & Route 53 CNAME Setup

This project sets up your custom domain via AWS Route 53 with an automated SSL certificate:

### Step 1 — Configure Terraform Variables
In `infrastructure/terraform/variables.tf` (or by using a `terraform.tfvars` file):
- `domain_name`: Your registered apex domain (e.g. `example.com` bought on GoDaddy, Namecheap, etc.)
- `subdomain`: Subdomain prefix for CNAME (e.g. `todo`, making `todo.example.com`)

### Step 2 — Provision Infrastructure with Terraform

```bash
cd infrastructure/terraform

terraform init
terraform plan \
  -var="key_name=your-ec2-keypair" \
  -var="dockerhub_image=yourusername/todo-app" \
  -var="domain_name=yourdomain.com" \
  -var="subdomain=todo"

terraform apply
```

Terraform creates:
1. **EC2 instance** (`t2.micro` running Ubuntu with Docker preinstalled).
2. **Security Group** with ports `80` (HTTP), `443` (HTTPS), and `22` (SSH) open.
3. **Route 53 Hosted Zone** for `yourdomain.com`.
4. **Route 53 CNAME Record** pointing `todo.yourdomain.com` directly to the EC2 Public DNS (`ec2-xx-xx.compute.amazonaws.com`).

### Step 3 — Point Registrar Nameservers to AWS Route 53
From the `terraform output`, copy the 4 `route53_name_servers`:
```
route53_name_servers = [
  "ns-123.awsdns-12.com",
  "ns-456.awsdns-34.net",
  "ns-789.awsdns-56.org",
  "ns-012.awsdns-78.co.uk",
]
```
1. Log in to your registrar dashboard (**GoDaddy**, **Namecheap**, **Hostinger**, etc.).
2. Go to your domain's **DNS / Nameservers** management section.
3. Switch from default nameservers to **Custom Nameservers**.
4. Paste the 4 AWS Route 53 nameservers and save.
5. *(Allow 5–15 minutes for worldwide DNS delegation to propagate).*

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
