# Containerization & Docker Optimization Guide

This guide details the container design, multi-stage builds, non-root security models, and OCI image labeling applied to the **Todo List Multi-Container Application**.

---

## 1. Backend Container (`backend/Dockerfile`)

### Multi-Stage Build Architecture
```dockerfile
# Stage 1: Dependencies Installation
FROM node:22-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Stage 2: Production Runtime
FROM node:22-alpine AS production
# Non-root user setup
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY backend/src/ ./src/
RUN chown -R appuser:appgroup /app
USER appuser
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "src/server.js"]
```

### Key Optimizations
- **Layer Caching:** Copies `package*.json` separately before application code so dependency installations are cached unless dependencies change.
- **Minimal Image Footprint:** Alpine base image (~180MB total vs ~1GB for standard Debian Node images).
- **Security Context:** Runs under UID `1000` (`appuser`) rather than `root`.
- **Signal Handling:** Direct `node src/server.js` execution receives and handles `SIGTERM` and `SIGINT` signals for graceful HTTP connection draining.

---

## 2. Frontend Container (`frontend/Dockerfile`)

```dockerfile
FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="Todo List Web UI Frontend" \
      org.opencontainers.image.description="Nginx static web server and reverse proxy" \
      org.opencontainers.image.licenses="MIT"

COPY frontend/nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY frontend/public/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### Key Optimizations
- **Static Asset Caching:** Configured Nginx to serve `.css`, `.js`, `.svg` with `Cache-Control: public, max-age=604800, immutable`.
- **Dynamic HTML:** Root `index.html` configured with `no-cache` to ensure browser clients always fetch the latest frontend assets.
- **Embedded Reverse Proxy:** Routes all `/api/*`, `/health`, and `/ready` requests directly to `http://backend:3000` via internal Kubernetes DNS.
