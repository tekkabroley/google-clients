#!/bin/bash

# Google Drive Client - macOS Shell Script
# This script sets up and runs the Google Drive Client container on macOS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo "  $1"
    echo -e "${CYAN}========================================${NC}"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if we're in the right place
if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
    print_error "Cannot find Docker files in $SCRIPT_DIR"
    print_error "Expected: $SCRIPT_DIR/Dockerfile"
    exit 1
fi

cd "$PROJECT_DIR"

print_header "Google Drive Client - macOS Setup"

# Check if Docker is installed
print_info "[1/5] Checking Docker installation..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    print_info ""
    print_info "To install Docker Desktop for Mac:"
    print_info "  1. Download from: https://www.docker.com/products/docker-desktop/"
    print_info "  2. Install Docker Desktop"
    print_info "  3. Start Docker Desktop"
    print_info "  4. Run this script again"
    print_info ""
    open "https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    print_error "Docker is installed but daemon is not running"
    print_info ""
    print_info "Please start Docker Desktop:"
    print_info "  - Open Docker Desktop from Applications"
    print_info "  - Wait for it to fully initialize (whale icon in menu bar)"
    print_info "  - Then run this script again"
    print_info ""
    exit 1
fi

print_success "Docker is installed and running"
print_info "Using: $(docker --version)"

# Create data directories if they don't exist
print_info "[2/5] Setting up directories..."

if [ ! -d "credentials" ]; then
    print_info "Creating directory structure..."
    mkdir -p credentials
    mkdir -p config
    mkdir -p data
    print_success "Directories created"
else
    print_info "Directories already exist"
fi

# Check for existing container
print_info "[3/5] Checking for existing container..."

if docker ps -a --format '{{.Names}}' | grep -q "^google-drive-client$"; then
    print_info "Container 'google-drive-client' already exists"
    
    if docker ps --format '{{.Names}}' | grep -q "^google-drive-client$"; then
        print_info "Container is already running"
        CONTAINER_RUNNING=true
    else
        print_info "Container exists but is stopped"
        CONTAINER_RUNNING=false
    fi
else
    print_info "No existing container found"
    CONTAINER_RUNNING=false
fi

# Build the Docker image
print_info "[4/5] Building Docker image..."

DOCKER_IMAGE=$(docker images -q google-drive-client 2>/dev/null || true)

if [ -z "$DOCKER_IMAGE" ]; then
    print_info "Building Docker image (this may take several minutes)..."
    if docker build -t google-drive-client -f google_drive_client/docker/Dockerfile .; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        print_error "Check Docker is running and your internet connection"
        exit 1
    fi
else
    print_info "Docker image already exists"
fi

# Start the container
print_info "[5/5] Starting container..."

if [ "$CONTAINER_RUNNING" = true ]; then
    print_info "Container is already running"
    print_success "Google Drive Client is ready!"
else
    if docker-compose -f google_drive_client/docker/docker-compose.yml up -d; then
        print_success "Container started successfully"
    else
        print_error "Failed to start with docker-compose, trying docker run..."
        if docker run -d --name google-drive-client -p 50200:50200 \
            -v "$(pwd)/credentials:/app/credentials" \
            -v "$(pwd)/config:/app/config" \
            -v "$(pwd)/data:/app/data" \
            google-drive-client; then
            print_success "Container started with docker run"
        else
            print_error "Failed to start container"
            exit 1
        fi
    fi
fi

# Give the container a moment to start
sleep 2

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "^google-drive-client$"; then
    print_header "Setup Complete!"
    print_success "Google Drive Client container is running"
else
    print_error "Container failed to start"
    print_info "Check logs with: docker logs google-drive-client"
    exit 1
fi

# Check if credentials exist
print_info ""
print_info "Checking for credentials..."

if [ ! -f "credentials/credentials.json" ] && [ ! -f "credentials/service-account.json" ]; then
    print_warning "No credentials found"
    print_info ""
    print_info "To use the Google Drive Client, you need to provide credentials:"
    print_info ""
    print_info "Option 1: For Service Account"
    print_info "  1. Copy your service account JSON to: credentials/service-account.json"
    print_info "  2. Run commands like: docker exec -it google-drive-client create 'My File' <folder-id>"
    print_info ""
    print_info "Option 2: For OAuth (interactive)"
    print_info "  Run this command to authorize:"
    print_info "    docker exec -it google-drive-client authorize <project-id> <client-id> <client-secret>"
    print_info "  This will open a browser for authentication"
    print_info "  Save the output to: credentials/credentials.json"
    print_info ""
    print_info "Option 3: Mount existing credentials"
    print_info "  Copy your credentials.json to: credentials/credentials.json"
    print_info ""
fi

print_header "All Done!"
print_info ""
print_info "How to use:"
print_info ""
print_info "  Common commands:"
print_info ""
print_info "    - Authorize OAuth:  docker exec -it google-drive-client authorize <project> <client-id> <secret>"
print_info "    - Create file:     docker exec -it google-drive-client create \"My File\" <folder-id>"
print_info "    - List files:      docker exec -it google-drive-client list-files <folder-id>"
print_info "    - Download file:    docker exec -it google-drive-client download <file-id> /app/data/output"
print_info "    - Share file:       docker exec -it google-drive-client share <file-id> reader --domain example.com"
print_info ""
print_info "  Note: Downloaded files will be in the 'data' directory on your host"
print_info ""
print_info "Useful commands:"
print_info "  - View logs:     docker logs -f google-drive-client"
print_info "  - Stop:          docker stop google-drive-client"
print_info "  - Start:        docker start google-drive-client"
print_info "  - Restart:      docker restart google-drive-client"
print_info "  - Shell:        docker exec -it google-drive-client bash"
print_info "  - Help:         docker exec -it google-drive-client --help"
print_info ""

# Ask if user wants to see help
read -p "Show CLI help now? (y/n) [n]: " -n 1 -r SHOW_HELP

echo

if [ -z "$SHOW_HELP" ] || [ "$SHOW_HELP" = "y" ] || [ "$SHOW_HELP" = "Y" ]; then
    print_info "Showing CLI help..."
    docker exec -it google-drive-client --help
fi
