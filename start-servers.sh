#!/bin/bash
set -e

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Function to start a supergateway instance for a server
start_server() {
    local name=$1
    local command=$2
    local port=$3
    local env_vars=$4
    
    log "Starting $name on port $port..."
    
    # Prepare environment variables
    local env_cmd=""
    if [ -n "$env_vars" ]; then
        # Export each variable
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [ -z "$key" ] && continue
            [[ "$key" =~ ^#.* ]] && continue
            
            # Remove quotes from value if present
            value=$(echo "$value" | sed -e "s/^['\"]//" -e "s/['\"]$//")
            
            # Export the variable
            export "$key"="$value"
            env_cmd="$env_cmd $key=\"$value\""
        done <<< "$env_vars"
    fi
    
    # Create log directory if it doesn't exist
    mkdir -p /app/logs
    
    # Start supergateway with environment variables
    eval $env_cmd npx -y supergateway \
        --stdio "$command" \
        --port "$port" \
        --baseUrl "http://localhost:$port" \
        --ssePath "/sse" \
        --messagePath "/message" \
        --cors \
        --healthEndpoint "/healthz" \
        --logLevel "info" \
        2>&1 | tee "/app/logs/$name.log" &
    
    local pid=$!
    echo "$pid" > "/tmp/$name.pid"
    
    # Wait a moment for the server to start
    sleep 2
    
    # Check if the process is still running
    if kill -0 "$pid" 2>/dev/null; then
        log "$name started successfully (PID: $pid)"
    else
        log "ERROR: $name failed to start. Check /app/logs/$name.log for details."
        return 1
    fi
    
    return 0
}

# Function to parse YAML configuration
parse_yaml() {
    local config_file=${1:-mcp-servers.yaml}
    
    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        log "ERROR: yq is not installed. Cannot parse YAML configuration."
        return 1
    fi
    
    # Get server count
    local server_count
    server_count=$(yq '.servers | length' "$config_file" 2>/dev/null || echo "0")
    
    if [ "$server_count" -eq 0 ]; then
        log "No servers defined in configuration file."
        return 0
    fi
    
    log "Found $server_count MCP server(s) in configuration"
    
    # Get server names
    local server_names
    mapfile -t server_names < <(yq '.servers | keys | .[]' "$config_file")
    
    # Array to track failed servers
    local failed_servers=()
    
    # Start each server
    for name in "${server_names[@]}"; do
        # Get server configuration
        local command port
        command=$(yq ".servers.$name.command" "$config_file")
        port=$(yq ".servers.$name.port" "$config_file")
        
        # Get environment variables
        local env_vars=""
        local env_count
        env_count=$(yq ".servers.$name.env | length" "$config_file" 2>/dev/null || echo "0")
        
        if [ "$env_count" -gt 0 ]; then
            # Extract environment variables as key=value pairs
            env_vars=$(yq ".servers.$name.env | to_entries | .[] | .key + \"=\" + .value" "$config_file")
        fi
        
        # Check if server requires Docker
        local requires_docker
        requires_docker=$(yq ".servers.$name.requires_docker" "$config_file" 2>/dev/null || echo "false")
        
        if [ "$requires_docker" = "true" ] && ! command -v docker &> /dev/null; then
            log "WARNING: $name requires Docker but Docker is not available. Skipping."
            failed_servers+=("$name")
            continue
        fi
        
        # Start the server
        if start_server "$name" "$command" "$port" "$env_vars"; then
            log "$name is running on http://localhost:$port/sse"
        else
            log "Failed to start $name"
            failed_servers+=("$name")
        fi
    done
    
    # Report failures
    if [ ${#failed_servers[@]} -gt 0 ]; then
        log "WARNING: The following servers failed to start: ${failed_servers[*]}"
    fi
    
    return ${#failed_servers[@]}
}

# Cleanup function
cleanup() {
    log "Shutting down servers..."
    
    # Kill all background processes
    for pidfile in /tmp/*.pid; do
        if [ -f "$pidfile" ]; then
            local pid name
            pid=$(cat "$pidfile")
            name=$(basename "$pidfile" .pid)
            
            if kill -0 "$pid" 2>/dev/null; then
                log "Stopping $name (PID: $pid)..."
                kill "$pid" && wait "$pid" 2>/dev/null || true
                log "$name stopped."
            fi
            
            rm "$pidfile"
        fi
    done
    
    exit 0
}

# Trap signals
trap cleanup SIGINT SIGTERM SIGQUIT

# Main execution
log "Starting MCP Gateway..."

# Check for configuration file
if [ ! -f "mcp-servers.yaml" ]; then
    log "Configuration file mcp-servers.yaml not found. Using default configuration."
    
    # Start a single example server on port 8000
    start_server "example" "npx -y @modelcontextprotocol/server-calculator" "8000" ""
else
    # Parse and start servers from YAML
    parse_yaml "mcp-servers.yaml"
fi

# Keep the script running
log "All servers started. Gateway is running."
log "Press Ctrl+C to stop."

# Wait for all background processes
wait