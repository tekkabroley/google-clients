#!/bin/bash

# Google Photos Sync - Setup Script
# This script installs dependencies and configures the environment

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

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_error "This setup script is designed for macOS only."
    exit 1
fi

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    log_warning "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "("/opt/homebrew/bin/brew" shellenv)"
    fi
fi

# Install rclone
if ! command -v rclone &> /dev/null; then
    log_info "Installing rclone..."
    brew install rclone
    log_success "rclone installed successfully"
else
    log_info "rclone is already installed (version: $(rclone version | head -1))"
fi

# Install fswatch
if ! command -v fswatch &> /dev/null; then
    log_info "Installing fswatch..."
    brew install fswatch
    log_success "fswatch installed successfully"
else
    log_info "fswatch is already installed"
fi

# Create directory structure
log_info "Creating directory structure..."
PHOTOS_SYNC_DIR="$HOME/Photos_Sync"
mkdir -p "$PHOTOS_SYNC_DIR/Watch"
mkdir -p "$PHOTOS_SYNC_DIR/Uploaded"
mkdir -p "$PHOTOS_SYNC_DIR/Logs"
log_success "Directories created at $PHOTOS_SYNC_DIR"

# Create config file
CONFIG_FILE="$PHOTOS_SYNC_DIR/config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_info "Creating configuration file..."
    cat > "$CONFIG_FILE" << 'EOF'
# Google Photos Sync Configuration
# Edit these values to match your setup

# Rclone remote name (default: google_photos)
RCLONE_REMOTE="google_photos"

# Target album in Google Photos
RCLONE_ALBUM="AutoSync"

# Directory paths
WATCH_DIR="$HOME/Photos_Sync/Watch"
UPLOADED_DIR="$HOME/Photos_Sync/Uploaded"
LOG_DIR="$HOME/Photos_Sync/Logs"

# Debounce settings (seconds)
DEBOUNCE_SLEEP=3
MAX_DEBOUNCE_ATTEMPTS=20

# Rclone options
RCLONE_OPTIONS="--progress --fast-list"
EOF
    log_success "Configuration file created at $CONFIG_FILE"
    log_info "Please edit $CONFIG_FILE to configure your rclone remote and album"
else
    log_info "Configuration file already exists at $CONFIG_FILE"
fi

# Check for rclone Google Photos configuration
log_info ""
log_info "==================================================="
log_info "  RCLONE GOOGLE PHOTOS CONFIGURATION REQUIRED"
log_info "==================================================="
log_info ""
log_info "Run the following command to configure rclone for Google Photos:"
log_info ""
log_info "  rclone config"
log_info ""
log_info "Steps:"
log_info "  1. Select 'n' for new remote"
log_info "  2. Enter a name (e.g., 'google_photos')"
log_info "  3. Select 'google photos' as the storage type"
log_info "  4. Follow the OAuth2 authentication in your browser"
log_info "  5. Select 'n' for advanced config"
log_info "  6. Select 'y' for auto config"
log_info ""
log_info "After configuration, update RCLONE_REMOTE in $CONFIG_FILE"
log_info ""

# Test rclone configuration
if rclone listremotes &> /dev/null; then
    log_info "Existing rclone remotes:"
    rclone listremotes | sed 's/^/  /'
else
    log_warning "No rclone remotes configured yet"
fi

# Make scripts executable
SCRIPT_DIR="$(dirname "$0")"
chmod +x "$SCRIPT_DIR/start_watch.sh" "$SCRIPT_DIR/upload_worker.sh"
log_success "Scripts made executable"

# Create launchd plist symlink (optional)
PLIST_FILE="$SCRIPT_DIR/com.local.google-photos-sync.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.local.google-photos-sync.plist"

if [[ -f "$PLIST_FILE" ]] && [[ ! -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME" ]]; then
    log_info "Creating launchd plist symlink..."
    mkdir -p "$LAUNCH_AGENTS_DIR"
    ln -s "$PLIST_FILE" "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
    log_success "launchd plist installed to $LAUNCH_AGENTS_DIR/$PLIST_NAME"
    log_info ""
    log_info "To start the service on login:"
    log_info "  launchctl load ~/Library/LaunchAgents/$PLIST_NAME"
    log_info "  launchctl start com.local.google-photos-sync"
else
    log_info "launchd plist already installed or not found"
fi

log_info ""
log_info "==================================================="
log_info "  SETUP COMPLETE"
log_info "==================================================="
log_info ""
log_info "Next steps:"
log_info "  1. Configure rclone: rclone config"
log_info "  2. Edit $CONFIG_FILE to set RCLONE_REMOTE and RCLONE_ALBUM"
log_info "  3. Start the monitor: ./start_watch.sh"
log_info "  4. (Optional) Enable auto-start with launchd"
log_info ""
