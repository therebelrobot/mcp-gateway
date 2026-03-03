# MCP Gateway

A multi-MCP server gateway for LibreChat that runs multiple Model Context Protocol (MCP) servers in a single Docker container using Supergateway as a bridge.

## Features

- **Multi-Server Support**: Run multiple MCP servers in a single container
- **Supergateway Bridge**: Convert stdio-based MCP servers to SSE endpoints
- **YAML Configuration**: Easy configuration via `mcp-servers.yaml`
- **Docker Integration**: Works seamlessly with Docker and Docker Compose
- **Health Checks**: Built-in health endpoints for monitoring
- **Logging**: Individual log files for each server
- **Process Management**: Automatic restart and process supervision

## Architecture

```
┌─────────────────────────────────────────────────┐
│               LibreChat Container               │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │            MCP Gateway Container        │   │
│  │                                         │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐ │   │
│  │  │ Brave   │  │  EMQX   │  │ Filesys │ │   │
│  │  │ Search  │  │  MCP    │  │   MCP   │ │   │
│  │  │ Port    │  │ Server  │  │ Server  │ │   │
│  │  │  8003   │  │  8004   │  │  8005   │ │   │
│  │  └─────────┘  └─────────┘  └─────────┘ │   │
│  │       ↑           ↑           ↑         │   │
│  │  ┌───────────────────────────────────┐  │   │
│  │  │        Supergateway Bridges       │  │   │
│  │  │   (stdio → SSE for each server)   │  │   │
│  │  └───────────────────────────────────┘  │   │
│  └─────────────────────────────────────────┘   │
│           ↑           ↑           ↑            │
│      http://.../sse  http://.../sse  http://.../sse
└─────────────────────────────────────────────────┘
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/therebelrobot/mcp-gateway.git
cd mcp-gateway
```

### 2. Configure Your MCP Servers

Edit `mcp-servers.yaml` to define which MCP servers to run:

```yaml
servers:
  brave-search:
    command: "npx -y @modelcontextprotocol/server-brave-search"
    port: 8003
    env:
      BRAVE_API_KEY: ${BRAVE_API_KEY}

  emqx:
    command: "docker run -i --rm -e EMQX_API_URL=${EMQX_API_URL} -e EMQX_API_KEY=${EMQX_API_KEY} -e EMQX_API_SECRET=${EMQX_API_SECRET} benniuji/emqx-mcp-server"
    port: 8004
    requires_docker: true
```

### 3. Build and Run

```bash
# Build the Docker image
docker build -t mcp-gateway .

# Run the container
docker run -d \
  -p 8003:8003 \
  -p 8004:8004 \
  -p 8005:8005 \
  -e BRAVE_API_KEY="your-brave-api-key" \
  -e EMQX_API_URL="https://your-emqx-cloud-instance.com:8443/api/v5" \
  -e EMQX_API_KEY="your-emqx-api-key" \
  -e EMQX_API_SECRET="your-emqx-api-secret" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ./data:/data \
  --name mcp-gateway \
  mcp-gateway
```

### 4. Integrate with LibreChat

Create a `librechat.yaml` file:

```yaml
mcpServers:
  brave-search:
    type: sse
    url: "http://mcp-gateway:8003/sse"
  
  emqx:
    type: sse
    url: "http://mcp-gateway:8004/sse"
  
  filesystem:
    type: sse
    url: "http://mcp-gateway:8005/sse"
```

## Docker Compose Integration

See `docker-compose.example.yml` for a complete example integrating with LibreChat:

```bash
# Copy example files
cp docker-compose.example.yml docker-compose.yml
cp librechat.yaml.example librechat.yaml

# Create .env file with your API keys
echo "BRAVE_API_KEY=your-brave-api-key" >> .env
echo "EMQX_API_KEY=your-emqx-api-key" >> .env
echo "EMQX_API_SECRET=your-emqx-api-secret" >> .env
echo "OPENAI_API_KEY=your-openai-api-key" >> .env

# Start all services
docker-compose up -d
```

## Configuration

### MCP Servers YAML Format

The `mcp-servers.yaml` file supports the following structure:

```yaml
servers:
  server-name:
    command: "command to run the MCP server"
    port: 8000  # Port for Supergateway to listen on
    env:  # Optional environment variables
      KEY: "value"
      ANOTHER_KEY: "${ENV_VAR_NAME}"
    requires_docker: false  # Set to true if command uses Docker
    volumes:  # Optional volume mounts (for filesystem access)
      - /host/path:/container/path
```

### Available MCP Servers

Here are some popular MCP servers you can integrate:

| Server | Command | Description |
|--------|---------|-------------|
| Brave Search | `npx -y @modelcontextprotocol/server-brave-search` | Web search using Brave Search API |
| Filesystem | `npx -y @modelcontextprotocol/server-filesystem /path` | File system access |
| Calculator | `npx -y @modelcontextprotocol/server-calculator` | Mathematical calculations |
| Git | `uvx mcp-server-git` | Git repository operations |
| Docker | `uvx mcp-server-docker` | Docker container management |
| SQLite | `uvx mcp-server-sqlite` | SQLite database operations |
| EMQX | `docker run ... benniuji/emqx-mcp-server` | EMQX MQTT broker management |
| Postgres | `uvx mcp-server-postgres` | PostgreSQL database operations |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `BRAVE_API_KEY` | Brave Search API key | For Brave Search |
| `EMQX_API_URL` | EMQX API URL | For EMQX |
| `EMQX_API_KEY` | EMQX API key | For EMQX |
| `EMQX_API_SECRET` | EMQX API secret | For EMQX |
| Other variables | As needed by your MCP servers | Depends on servers |

## Building for Different Architectures

### For Raspberry Pi (ARM64)

```bash
# Build for ARM64
docker buildx build --platform linux/arm64 -t therebelrobot/mcp-gateway:arm64 .

# Push to GitHub Container Registry
docker push therebelrobot/mcp-gateway:arm64
```

### Multi-Architecture Build

```bash
# Create and use buildx builder
docker buildx create --name multiarch --use

# Build for multiple architectures
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t therebelrobot/mcp-gateway:latest \
  --push .
```

## GitHub Container Registry

### Push to GHCR

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u therebelrobot --password-stdin

# Build and push
docker build -t ghcr.io/therebelrobot/mcp-gateway:latest .
docker push ghcr.io/therebelrobot/mcp-gateway:latest
```

### Pull on Raspberry Pi

```bash
docker pull ghcr.io/therebelrobot/mcp-gateway:latest
docker run -d \
  -p 8003:8003 \
  -p 8004:8004 \
  -e BRAVE_API_KEY="your-key" \
  ghcr.io/therebelrobot/mcp-gateway:latest
```

## Troubleshooting

### Check Logs

```bash
# View container logs
docker logs mcp-gateway

# View individual server logs
docker exec mcp-gateway cat /app/logs/brave-search.log
```

### Health Checks

Each Supergateway instance provides a health endpoint:

```bash
# Check if a server is healthy
curl http://localhost:8003/healthz
```

### Common Issues

1. **Docker socket permission denied**: Ensure the Docker socket is readable by the container user.
   ```bash
   chmod 666 /var/run/docker.sock
   ```

2. **Port already in use**: Change the port number in `mcp-servers.yaml`.

3. **Missing environment variables**: Ensure all required environment variables are set.

4. **YAML parsing errors**: Use `yq` to validate your YAML:
   ```bash
   yq eval mcp-servers.yaml
   ```

## Development

### Adding New MCP Servers

1. Add the server to `mcp-servers.yaml`
2. Update the startup script if needed
3. Rebuild the Docker image

### Customizing the Startup Script

The `start-servers.sh` script can be customized to:
- Add pre-start hooks
- Modify environment variables
- Implement custom health checks
- Add monitoring integration

### Using Supervisor (Alternative)

The image includes Supervisor for process management. To use it:

1. Edit `supervisord.conf` to define your servers
2. Update the Dockerfile CMD to:
   ```dockerfile
   CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
   ```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

- Create an issue on GitHub
- Check the [LibreChat documentation](https://www.librechat.ai/docs/features/mcp)
- Refer to the [Supergateway documentation](https://github.com/supercorp-ai/supergateway)