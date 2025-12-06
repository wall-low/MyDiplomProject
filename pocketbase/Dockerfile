# PocketBase Dockerfile for production deployment
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    ca-certificates \
    unzip \
    wget \
    curl

# Set working directory
WORKDIR /app

# Download PocketBase (latest version)
# Check https://github.com/pocketbase/pocketbase/releases for the latest version
ARG PB_VERSION=0.22.0
RUN wget https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip \
    && unzip pocketbase_${PB_VERSION}_linux_amd64.zip \
    && rm pocketbase_${PB_VERSION}_linux_amd64.zip \
    && chmod +x pocketbase

# Create directories for data persistence
RUN mkdir -p /app/pb_data /app/pb_migrations

# Expose PocketBase default port
EXPOSE 8090

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8090/api/health || exit 1

# Run PocketBase
CMD ["/app/pocketbase", "serve", "--http=0.0.0.0:8090"]
