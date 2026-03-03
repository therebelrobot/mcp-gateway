#!/bin/bash

# Test script for MCP Gateway configuration
# This script validates the YAML configuration and checks dependencies

set -e

echo "🔍 Testing MCP Gateway configuration..."

# Check for required commands
for cmd in docker yq curl; do
    if command -v $cmd &> /dev/null; then
        echo "✅ $cmd is available"
    else
        echo "❌ $cmd is not available"
        if [ "$cmd" = "yq" ]; then
            echo "   Install yq with: wget -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && chmod +x /usr/local/bin/yq"
        fi
    fi
done

# Check for configuration file
if [ -f "mcp-servers.yaml" ]; then
    echo "✅ Configuration file found: mcp-servers.yaml"
    
    # Validate YAML syntax
    if command -v yq &> /dev/null; then
        if yq . mcp-servers.yaml > /dev/null 2>&1; then
            echo "✅ YAML syntax is valid"
            
            # Count servers
            server_count=$(yq '.servers | length' mcp-servers.yaml 2>/dev/null || echo "0")
            echo "📊 Found $server_count MCP server(s) in configuration"
            
            # List servers
            if [ "$server_count" -gt 0 ]; then
                echo ""
                echo "📋 Configured MCP Servers:"
                echo "-------------------------"
                yq '.servers | to_entries | .[] | "• " + .key + " (Port: " + (.value.port | tostring) + ")"' mcp-servers.yaml
                
                # Check for Docker requirements
                echo ""
                echo "🔧 Docker Requirements:"
                echo "----------------------"
                for server in $(yq '.servers | keys | .[]' mcp-servers.yaml); do
                    requires_docker=$(yq ".servers.$server.requires_docker" mcp-servers.yaml 2>/dev/null || echo "false")
                    if [ "$requires_docker" = "true" ]; then
                        echo "⚠️  $server requires Docker socket access"
                    fi
                done
            fi
        else
            echo "❌ YAML syntax error in mcp-servers.yaml"
        fi
    fi
else
    echo "❌ Configuration file not found: mcp-servers.yaml"
    echo "   Using default configuration (calculator on port 8000)"
fi

# Check Docker socket access
if [ -S "/var/run/docker.sock" ]; then
    echo "✅ Docker socket found: /var/run/docker.sock"
    
    # Check permissions
    if [ -r "/var/run/docker.sock" ]; then
        echo "✅ Docker socket is readable"
    else
        echo "❌ Docker socket is not readable"
        echo "   Fix with: sudo chmod 666 /var/run/docker.sock"
    fi
else
    echo "⚠️  Docker socket not found (optional for non-Docker MCP servers)"
fi

# Check for required environment variables
echo ""
echo "🌍 Environment Variables Check:"
echo "-----------------------------"

# Common environment variables to check
declare -A env_vars
env_vars["BRAVE_API_KEY"]="Required for Brave Search MCP server"
env_vars["EMQX_API_KEY"]="Required for EMQX MCP server"
env_vars["EMQX_API_SECRET"]="Required for EMQX MCP server"

for var in "${!env_vars[@]}"; do
    if [ -n "${!var}" ]; then
        echo "✅ $var is set"
    else
        echo "⚠️  $var is not set: ${env_vars[$var]}"
    fi
done

echo ""
echo "📦 Docker Image Information:"
echo "---------------------------"

# Check if we can build Docker image
if [ -f "Dockerfile" ]; then
    echo "✅ Dockerfile found"
    
    # Check Dockerfile contents
    if grep -q "supergateway" Dockerfile; then
        echo "✅ Dockerfile includes supergateway"
    fi
    
    if grep -q "node:18-alpine" Dockerfile; then
        echo "✅ Dockerfile uses Node.js 18 Alpine base"
    fi
else
    echo "❌ Dockerfile not found"
fi

echo ""
echo "🎉 Configuration test complete!"
echo ""
echo "Next steps:"
echo "1. Edit mcp-servers.yaml to configure your MCP servers"
echo "2. Set required environment variables"
echo "3. Build the Docker image: docker build -t mcp-gateway ."
echo "4. Run the container: docker run -d -p 8000-8099:8000-8099 mcp-gateway"