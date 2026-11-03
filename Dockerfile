# ─── Stage 1: Base ────────────────────────────────────────────────────────────
FROM node:22-alpine AS base
WORKDIR /app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ─── Stage 2: Production image ────────────────────────────────────────────────
FROM node:22-alpine AS production

# Create a non-root user for security (Alpine syntax)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy installed node_modules from base stage
COPY --from=base /app/node_modules ./node_modules

# Copy application source
COPY src/ ./src/

# Secure the working directory permissions
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

# Health check — uses wget since it is built natively into Alpine
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]
