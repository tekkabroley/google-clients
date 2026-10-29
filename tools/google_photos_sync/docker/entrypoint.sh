#!/bin/bash

# Google Photos Sync - Docker Entry Point
# This script adapts the tool to work in a container environment

set -euo pipefail

# Set up environment
APP_DIR="/app"
DATA_DIR="/app/data"
CONFIG_DIR="/app/data/config"

# Create directories if they don't exist
mkdir -p "$DATA_DIR/Watch" "$DATA_DIR/Uploaded" "$DATA_DIR/Logs" "$CONFIG_DIR"

# Ensure config file exists
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/config.env}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating default configuration file at $CONFIG_FILE"
    cat > "$CONFIG_FILE" << 'EOF'
# Google Photos Sync Configuration
# Edit these values to match your setup

# Rclone remote name (default: google_photos)
RCLONE_REMOTE="google_photos"

# Target album in Google Photos
RCLONE_ALBUM="AutoSync"

# Directory paths
WATCH_DIR="/app/data/Watch"
UPLOADED_DIR="/app/data/Uploaded"
LOG_DIR="/app/data/Logs"

# Debounce settings (seconds)
DEBOUNCE_SLEEP=3
MAX_DEBOUNCE_ATTEMPTS=20

# Rclone options
RCLONE_OPTIONS="--progress --fast-list"
EOF
    echo "Default configuration created. Please edit $CONFIG_FILE with your settings."
fi

# Set environment variables for the container
if [ -f "$CONFIG_FILE" ]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

# Ensure rclone config directory exists
mkdir -p "$(dirname "${RCLONE_CONFIG:-/app/data/config/rclone.conf}")"

# Check if rclone is configured
if [ ! -f "${RCLONE_CONFIG:-/app/data/config/rclone.conf}" ]; then
    echo ""
    echo "=========================================="
    echo "  RCLONE CONFIGURATION NEEDED"
    echo "=========================================="
    echo ""
    echo "To configure rclone for Google Photos:"
    echo "  1. Run this container interactively:"
    echo "     docker run -it -v $(dirname $CONFIG_FILE):/app/data/config google-photos-sync bash"
    echo "  2. Inside the container, run: rclone config"
    echo "  3. Follow the prompts to create a 'google_photos' remote"
    echo ""
    echo "Or mount your existing rclone config:"
    echo "  docker run -v ~/.config/rclone/rclone.conf:/app/data/config/rclone.conf ..."
    echo ""
fi

# Export environment variables for Python
if [ -f "$CONFIG_FILE" ]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

# Check if this is a watch/start command - use container-compatible versions
if [ "${1:-}" = "start" ] || [ "${1:-}" = "watch" ] || [ "${1:-}" = "start_watch.sh" ]; then
    echo "Starting container-compatible file watcher..."
    exec /app/google_photos_sync/start_watch_container.sh "$@"
elif [ "${1:-}" = "setup" ] || [ "${1:-}" = "setup.sh" ]; then
    echo "Running container setup..."
    exec /app/google_photos_sync/setup_container.sh "$@"
fi

# For all other commands, use the Python CLI
exec python -m tools.google_photos_sync.cli "$@"
