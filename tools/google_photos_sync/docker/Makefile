# Makefile for Google Photos Sync Docker container
# Usage: make <target>

.PHONY: help build run stop restart logs shell setup status upload clean

# Configuration
IMAGE_NAME := google-photos-sync
DOCKER_COMPOSE := docker-compose -f docker-compose.yml
DOCKER_FILE := Dockerfile
VOLUME_NAME := google-photos-sync-data
CURDIR := $(shell pwd)

help: ## Show this help message
	@echo "Google Photos Sync - Docker Management"
	@echo "====================================="
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\n  %-20s %s", $$1, $$2}'
	@echo ""
	@echo ""

# Build the Docker image
build: ## Build the Docker image
	docker build -t $(IMAGE_NAME) -f $(DOCKER_FILE) ../..

# Run the container in detached mode
run: ## Start the container in detached mode
	docker run -d \
		--name $(IMAGE_NAME) \
		-v $(CURDIR)/../Photos_Sync:/app/data \
		$(IMAGE_NAME) start

# Stop the container
stop: ## Stop the running container
	@if docker ps -a | grep -q $(IMAGE_NAME); then \
		docker stop $(IMAGE_NAME); \
	fi

# Remove the container
rm: ## Remove the container
	@if docker ps -a | grep -q $(IMAGE_NAME); then \
		docker rm $(IMAGE_NAME); \
	fi

# Restart the container
restart: stop run ## Stop and restart the container

# View logs
logs: ## View container logs
	@if docker ps -a | grep -q $(IMAGE_NAME); then \
		docker logs -f $(IMAGE_NAME); \
	else \
		@echo "Container $(IMAGE_NAME) is not running"; \
	fi

# Open a shell in the container
shell: ## Open a shell in the running container
	@if docker ps | grep -q $(IMAGE_NAME); then \
		docker exec -it $(IMAGE_NAME) bash; \
	else \
		@echo "Container $(IMAGE_NAME) is not running. Starting a new one..."; \
		docker run -it --rm \
			--name $(IMAGE_NAME)-shell \
			-v $(CURDIR)/../Photos_Sync:/app/data \
			$(IMAGE_NAME) bash; \
	fi

# Run setup in the container
setup: ## Run setup in the container
	docker run -it --rm \
		-v $(CURDIR)/../Photos_Sync:/app/data \
		$(IMAGE_NAME) setup

# Check status
status: ## Check the status of the sync system
	docker run --rm \
		-v $(CURDIR)/../Photos_Sync:/app/data \
		$(IMAGE_NAME) status

# Upload a single file
upload: ## Upload a single file to Google Photos
	@if [ -z "${FILE}" ]; then \
		@echo "Error: FILE environment variable not set"; \
		@echo "Usage: FILE=/path/to/file.jpg make upload"; \
		@exit 1; \
	fi
	docker run --rm \
		-v $(CURDIR)/../Photos_Sync:/app/data \
		-v $(FILE):/tmp/upload_file \
		$(IMAGE_NAME) upload /tmp/upload_file

# Build and run with docker-compose
up: ## Start services with docker-compose
	$(DOCKER_COMPOSE) up -d

down: ## Stop and remove containers with docker-compose
	$(DOCKER_COMPOSE) down

# Build with docker-compose
build-compose: ## Build with docker-compose
	$(DOCKER_COMPOSE) build

# Clean - stop and remove container, and remove image
clean: stop rm ## Stop and remove container
	@echo "Removing image..."
	docker rmi $(IMAGE_NAME) 2>/dev/null || true

# Clean all - remove container, image, and volumes
clean-all: clean ## Clean everything including volumes
	@echo "Removing volumes..."
	docker volume rm $(VOLUME_NAME) 2>/dev/null || true

# Rebuild - clean and rebuild
rebuild: clean build ## Clean and rebuild the image

# View container info
ps: ## Show running containers
	docker ps -a --filter "name=$(IMAGE_NAME)"

# View images
images: ## Show Docker images
	docker images $(IMAGE_NAME)

# Test the container
test: build ## Test the container
	@echo "Testing container..."
	docker run --rm \
		$(IMAGE_NAME) --help
