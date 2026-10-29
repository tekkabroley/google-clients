#!/bin/bash

# Google Photos Sync - Container Setup Script
# This script sets up the container environment for Google Photos Sync

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Configuration
DATA_DIR="/app/data"
CONFIG_DIR="$DATA_DIR/config"
WATCH_DIR="$DATA_DIR/Watch"
UPLOADED_DIR="$DATA_DIR/Uploaded"
LOG_DIR="$DATA_DIR/Logs"
CONFIG_FILE="$CONFIG_DIR/config.env"
RCLONE_CONFIG="$CONFIG_DIR/rclone.conf"

# Create directory structure
log_info "Creating directory structure..."
mkdir -p "$WATCH_DIR" "$UPLOADED_DIR" "$LOG_DIR" "$CONFIG_DIR"
log_success "Directories created at $DATA_DIR"

# Create default config file if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_info "Creating default configuration file..."
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
    log_success "Default configuration file created at $CONFIG_FILE"
    log_info "Please edit $CONFIG_FILE to configure your rclone remote and album"
else
    log_info "Configuration file already exists at $CONFIG_FILE"
fi

# Check if rclone is installed
if command -v rclone &> /dev/null; then
    log_info "rclone is installed (version: $(rclone version | head -1))"
else
    log_error "rclone is not installed!"
    exit 1
fi

# Check if rclone is configured
if [[ -f "$RCLONE_CONFIG" ]]; then
    log_info "rclone configuration file exists at $RCLONE_CONFIG"
    if rclone listremotes --config="$RCLONE_CONFIG" 2>/dev/null; then
        log_info "Existing rclone remotes:"
        rclone listremotes --config="$RCLONE_CONFIG" | sed 's/^/  /'
    fi
else
    log_warning "rclone configuration file not found at $RCLONE_CONFIG"
    log_info ""
    log_info "=================================================="
    log_info "  RCLONE CONFIGURATION INSTRUCTIONS"
    log_info "=================================================="
    log_info ""
    log_info "To configure rclone for Google Photos:"
    log_info ""
    log_info "  Method 1: Configure inside the container"
    log_info "    docker exec -it <container_name> rclone config --config=$RCLONE_CONFIG"
    log_info ""
    log_info "  Method 2: Mount your existing rclone config"
    log_info "    docker run -v ~/.config/rclone/rclone.conf:$RCLONE_CONFIG ..."
    log_info ""
    log_info "  Method 3: Configure interactively"
    log_info "    docker run -it -v $CONFIG_DIR:/app/data/config google-photos-sync rclone config --config=$RCLONE_CONFIG"
    log_info ""
    log_info "Steps for configuration:"
    log_info "  1. Select 'n' for new remote"
    log_info "  2. Enter a name (e.g., 'google_photos')"
    log_info "  3. Select 'google photos' as the storage type"
    log_info "  4. Follow the OAuth2 authentication in your browser"
    log_info "  5. Select 'n' for advanced config"
    log_info "  6. Select 'y' for auto config"
    log_info ""
fi

# Check if inotifywait is installed
if command -v inotifywait &> /dev/null; then
    log_info "inotifywait is installed for file monitoring"
else
    log_warning "inotifywait is not installed. File monitoring will not work."
fi

# Make scripts executable
SCRIPT_DIR="/app/google_photos_sync"
chmod +x "$SCRIPT_DIR/start_watch_container.sh" "$SCRIPT_DIR/upload_worker_container.sh"
log_success "Scripts made executable"

log_info ""
log_info "=================================================="
log_info "  SETUP COMPLETE (Container)"
log_info "=================================================="
log_info ""
log_info "To use Google Photos Sync in Docker:"
log_info ""
log_info "  1. Configure rclone (if not done):"
log_info "     docker exec -it <container> rclone config --config=$RCLONE_CONFIG"
log_info ""
log_info "  2. Edit configuration:"
log_info "     docker exec -it <container> nano $CONFIG_FILE"
log_info ""
log_info "  3. Start the monitor:"
log_info "     docker exec -it <container> google-photos-sync start"
log_info ""
log_info "  4. Or run a one-time upload:"
log_info "     docker exec -it <container> google-photos-sync upload /path/to/file.jpg"
log_info ""
