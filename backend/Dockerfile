# Stage 1: Dependencies build stage
FROM node:22-alpine AS dependencies

WORKDIR /app

# Copy package files for dependency caching
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Stage 2: Production runtime stage
FROM node:22-alpine AS production

LABEL org.opencontainers.image.title="Todo List REST API Backend" \
      org.opencontainers.image.description="Node.js and Express REST API for Todo List Multi-Container Application" \
      org.opencontainers.image.source="https://github.com/pratik0207/todo-list-multi-container" \
      org.opencontainers.image.licenses="MIT"

# Create unprivileged application user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy node_modules from dependencies stage and backend source files
COPY --from=dependencies /app/node_modules ./node_modules
COPY backend/src/ ./src/

# Assign permissions
RUN chown -R appuser:appgroup /app

USER appuser

ENV NODE_ENV=production \
    PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

# Run Node.js directly
CMD ["node", "src/server.js"]
