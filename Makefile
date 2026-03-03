# Makefile for MCP Gateway

.PHONY: help build run test clean push arm64 amd64 multiarch

help: ## Display this help message
	@echo "Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build Docker image
	docker build -t mcp-gateway .

run: ## Run the container locally
	docker run -d \
		-p 8003:8003 \
		-p 8004:8004 \
		-p 8005:8005 \
		-p 8006:8006 \
		-p 8007:8007 \
		-p 8008:8008 \
		-p 8009:8009 \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v ./data:/data \
		--name mcp-gateway \
		mcp-gateway

stop: ## Stop running container
	docker stop mcp-gateway || true
	docker rm mcp-gateway || true

logs: ## View container logs
	docker logs -f mcp-gateway

test: ## Test configuration
	chmod +x test-config.sh
	./test-config.sh

shell: ## Open shell in running container
	docker exec -it mcp-gateway /bin/bash

clean: ## Remove Docker images and containers
	docker stop mcp-gateway || true
	docker rm mcp-gateway || true
	docker rmi mcp-gateway || true

# GitHub Container Registry targets
ghcr-login: ## Login to GitHub Container Registry
	echo "$$GITHUB_TOKEN" | docker login ghcr.io -u therebelrobot --password-stdin

push: ## Push to GitHub Container Registry
	docker tag mcp-gateway ghcr.io/therebelrobot/mcp-gateway:latest
	docker push ghcr.io/therebelrobot/mcp-gateway:latest

# Multi-architecture builds
arm64: ## Build for ARM64 (Raspberry Pi)
	docker buildx build --platform linux/arm64 -t ghcr.io/therebelrobot/mcp-gateway:arm64 .

amd64: ## Build for AMD64
	docker buildx build --platform linux/amd64 -t ghcr.io/therebelrobot/mcp-gateway:amd64 .

multiarch: ## Build for multiple architectures and push
	docker buildx create --name multiarch --use
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t ghcr.io/therebelrobot/mcp-gateway:latest \
		--push .

# Development targets
dev: ## Run in development mode with logs
	docker run --rm \
		-p 8003:8003 \
		-p 8004:8004 \
		-p 8005:8005 \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v ./data:/data \
		--name mcp-gateway-dev \
		mcp-gateway

compose-up: ## Start with docker-compose
	docker-compose -f docker-compose.example.yml up -d

compose-down: ## Stop docker-compose
	docker-compose -f docker-compose.example.yml down

compose-logs: ## View docker-compose logs
	docker-compose -f docker-compose.example.yml logs -f