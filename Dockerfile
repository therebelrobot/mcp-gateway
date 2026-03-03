FROM node:18-alpine

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    docker-cli \
    docker-compose \
    supervisor

# Install yq for YAML parsing
RUN wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

# Install supergateway globally
RUN npm install -g supergateway

# Create app directory
WORKDIR /app

# Copy configuration files
COPY mcp-servers.yaml .
COPY start-servers.sh .
COPY supervisord.conf /etc/supervisor/conf.d/

# Make scripts executable
RUN chmod +x start-servers.sh

# Create non-root user
RUN addgroup -g 1000 nodegroup && \
    adduser -u 1000 -G nodegroup -s /bin/bash -D nodeuser && \
    chown -R nodeuser:nodegroup /app

# Expose a range of ports (8000-8099 by default)
EXPOSE 8000-8099

# Switch to non-root user
USER nodeuser

# Default command - can be overridden
CMD ["/bin/bash", "./start-servers.sh"]