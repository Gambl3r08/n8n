# Dockerfile for n8n deployment in Minikube
# Based on Node.js 22 with optimizations for Kubernetes

FROM node:22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++ cairo-dev jpeg-dev pango-dev giflib-dev

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages ./packages
COPY patches ./patches

# Install pnpm
RUN npm install -g pnpm@10.12.1

# Install dependencies and build
RUN pnpm install --frozen-lockfile
RUN pnpm build

# Production stage
FROM node:22-alpine AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    tini \
    su-exec \
    cairo \
    jpeg \
    pango \
    giflib \
    python3 \
    make \
    g++ \
    sqlite

# Create app user
RUN addgroup -g 1000 n8n && \
    adduser -u 1000 -G n8n -s /bin/sh -D n8n

# Set working directory
WORKDIR /home/n8n

# Copy built application from builder stage
COPY --from=builder --chown=n8n:n8n /app/packages/cli/dist ./dist
COPY --from=builder --chown=n8n:n8n /app/packages/cli/package.json ./
COPY --from=builder --chown=n8n:n8n /app/node_modules ./node_modules

# Install only production dependencies for CLI
RUN npm install --only=production

# Create necessary directories
RUN mkdir -p /home/n8n/.n8n && \
    chown -R n8n:n8n /home/n8n

# Set environment variables
ENV NODE_ENV=production
ENV N8N_USER_FOLDER=/home/n8n/.n8n
ENV WEBHOOK_URL=http://localhost:5678/
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=http
ENV N8N_HOST=0.0.0.0

# Expose port
EXPOSE 5678

# Switch to non-root user
USER n8n

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5678/healthz || exit 1

# Use tini as init system
ENTRYPOINT ["tini", "--"]

# Start n8n
CMD ["node", "./dist/index.js"]
