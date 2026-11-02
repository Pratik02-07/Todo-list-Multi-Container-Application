# ─── Stage 1: Base ────────────────────────────────────────────────────────────
FROM node:18-alpine AS base
WORKDIR /app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm ci --only=production

# ─── Stage 2: Production image ────────────────────────────────────────────────
FROM node:18-alpine AS production

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy installed node_modules from base stage
COPY --from=base /app/node_modules ./node_modules

# Copy application source
COPY src/ ./src/

# Own the working directory
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

# Health check — Docker will restart the container if this fails
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]

