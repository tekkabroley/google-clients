#!/bin/bash

# Google Photos Sync - macOS Quick Run Script
# Quick script to start the container (after initial setup)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_info "Starting Google Photos Sync container..."

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running"
    print_info "Please start Docker Desktop and try again"
    exit 1
fi

# Check if container exists
if docker ps -a --format '{{.Names}}' | grep -q "^google-photos-sync$"; then
    print_info "Container exists. Starting it..."
    if docker start google-photos-sync; then
        print_success "Container started"
    else
        print_error "Failed to start container"
        exit 1
    fi
else
    print_info "Container not found. Building and starting..."
    if docker build -t google-photos-sync -f tools/google_photos_sync/docker/Dockerfile . > /dev/null 2>&1; then
        if docker-compose -f tools/google_photos_sync/docker-compose.yml up -d; then
            print_success "Container built and started"
        else
            print_error "Failed to start with docker-compose"
            exit 1
        fi
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
fi

# Wait a moment for container to initialize
sleep 2

# Check if it's running
if docker ps --format '{{.Names}}' | grep -q "^google-photos-sync$"; then
    print_success "Google Photos Sync is now running!"
    print_info ""
    print_info "To use:"
    print_info "  - Drop photos into: Photos_Sync/Watch/"
    print_info "  - View logs:     docker logs -f google-photos-sync"
    print_info "  - Stop:          docker stop google-photos-sync"
    print_info "  - Status:        docker exec google-photos-sync google-photos-sync status"
else
    print_error "Container failed to start"
    print_info "Check logs with: docker logs google-photos-sync"
    exit 1
fi
