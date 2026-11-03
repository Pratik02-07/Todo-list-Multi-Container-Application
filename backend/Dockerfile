# Stage 1: Install production dependencies
FROM node:22-alpine AS base

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Stage 2: Production image
FROM node:22-alpine AS production

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=base /app/node_modules ./node_modules
COPY backend/src/ ./src/

RUN chown -R appuser:appgroup /app

USER appuser

ENV NODE_ENV=production

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "src/server.js"]
