#!/bin/bash

# Google Photos Sync - macOS Shell Script
# This script sets up and runs the Google Photos Sync container on macOS

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
DOCKER_DIR="$SCRIPT_DIR/docker"

# Check if we're in the right place
if [ ! -f "$DOCKER_DIR/Dockerfile" ]; then
    print_error "Cannot find Docker files in $DOCKER_DIR"
    print_error "Expected: $DOCKER_DIR/Dockerfile"
    print_error "Current directory: $(pwd)"
    exit 1
fi

cd "$PROJECT_DIR"

print_header "Google Photos Sync - macOS Setup"

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

if [ ! -d "Photos_Sync" ]; then
    print_info "Creating Photos_Sync directory structure..."
    mkdir -p Photos_Sync/Watch
    mkdir -p Photos_Sync/Uploaded
    mkdir -p Photos_Sync/Logs
    mkdir -p Photos_Sync/config
    print_success "Directories created"
else
    print_info "Photos_Sync directory already exists"
fi

# Check for existing container
print_info "[3/5] Checking for existing container..."

if docker ps -a --format '{{.Names}}' | grep -q "^google-photos-sync$"; then
    print_info "Container 'google-photos-sync' already exists"
    
    if docker ps --format '{{.Names}}' | grep -q "^google-photos-sync$"; then
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

DOCKER_IMAGE=$(docker images -q google-photos-sync 2>/dev/null || true)

if [ -z "$DOCKER_IMAGE" ]; then
    print_info "Building Docker image (this may take several minutes)..."
    if docker build -t google-photos-sync -f tools/google_photos_sync/docker/Dockerfile .; then
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
    print_success "Google Photos Sync is ready!"
else
    if docker-compose -f tools/google_photos_sync/docker-compose.yml up -d; then
        print_success "Container started successfully"
    else
        print_error "Failed to start with docker-compose, trying docker run..."
        if docker run -d --name google-photos-sync -v "$(pwd)/Photos_Sync:/app/data" google-photos-sync start; then
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
if docker ps --format '{{.Names}}' | grep -q "^google-photos-sync$"; then
    print_header "Setup Complete!"
    print_success "Google Photos Sync container is running"
else
    print_error "Container failed to start"
    print_info "Check logs with: docker logs google-photos-sync"
    exit 1
fi

print_info ""
print_info "Next steps:"
print_info ""
print_info "  1. Configure rclone (if not already configured):"
print_info "     docker exec -it google-photos-sync rclone config --config=/app/data/config/rclone.conf"
print_info ""
print_info "  2. Edit your configuration:"
print_info "     File: $(pwd)/Photos_Sync/config/config.env"
print_info "     Set: RCLONE_REMOTE=google_photos"
print_info "     Set: RCLONE_ALBUM=YourAlbumName"
print_info ""
print_info "  3. Add photos to sync:"
print_info "     Copy files to: $(pwd)/Photos_Sync/Watch/"
print_info ""
print_info "  4. View logs:"
print_info "     docker logs -f google-photos-sync"
print_info ""
print_info "  5. Check status:"
print_info "     docker exec google-photos-sync google-photos-sync status"
print_info ""

# Create default config if it doesn't exist
if [ ! -f "Photos_Sync/config/config.env" ]; then
    print_info "Creating default configuration file..."
    docker exec google-photos-sync bash -c "if [ ! -f /app/data/config/config.env ]; then /app/google_photos_sync/setup_container.sh; fi"
    print_success "Default configuration created"
    print_info "Please edit Photos_Sync/config/config.env with your settings"
fi

# Ask if user wants to configure rclone now
read -p "Configure rclone now? (y/n) [y]: " -n 1 -r CONFIGURE_NOW

echo

if [ -z "$CONFIGURE_NOW" ] || [ "$CONFIGURE_NOW" = "y" ] || [ "$CONFIGURE_NOW" = "Y" ]; then
    print_info "Starting rclone configuration..."
    print_info "Follow the prompts to authenticate with Google Photos"
    docker exec -it google-photos-sync rclone config --config=/app/data/config/rclone.conf
fi

# Ask if user wants to edit config now
read -p "Edit configuration file now? (y/n) [y]: " -n 1 -r EDIT_CONFIG

echo

if [ -z "$EDIT_CONFIG" ] || [ "$EDIT_CONFIG" = "y" ] || [ "$EDIT_CONFIG" = "Y" ]; then
    if command -v open &> /dev/null; then
        print_info "Opening config file in TextEdit..."
        open "Photos_Sync/config/config.env"
    else
        print_info "Config file location: Photos_Sync/config/config.env"
        print_info "Edit it with your preferred editor"
    fi
fi

print_header "All Done!"
print_info ""
print_info "Your Google Photos Sync is now running in Docker."
print_info ""
print_info "How to use:"
print_info "  - Drop photos into: Photos_Sync/Watch/"
print_info "  - They will automatically upload to Google Photos"
print_info "  - Uploaded files move to: Photos_Sync/Uploaded/"
print_info ""
print_info "Useful commands:"
print_info "  - Start:    docker start google-photos-sync"
print_info "  - Stop:     docker stop google-photos-sync"
print_info "  - Restart:  docker restart google-photos-sync"
print_info "  - Logs:     docker logs -f google-photos-sync"
print_info "  - Status:   docker exec google-photos-sync google-photos-sync status"
print_info "  - Shell:    docker exec -it google-photos-sync bash"
print_info ""
