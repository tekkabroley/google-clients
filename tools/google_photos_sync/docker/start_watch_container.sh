#!/bin/bash

# Google Photos Sync - Container-compatible File Watch Monitor
# This version uses inotifywait (Linux) instead of fswatch (macOS)
# It works in Docker containers on both Windows and Mac hosts

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Try to load config
CONFIG_FILE="${CONFIG_FILE:-/app/data/config/config.env}"

# Default values
WATCH_DIR="${WATCH_DIR:-/app/data/Watch}"
LOG_DIR="${LOG_DIR:-/app/data/Logs}"
UPLOADED_DIR="${UPLOADED_DIR:-/app/data/Uploaded}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPLOAD_WORKER="$SCRIPT_DIR/upload_worker_container.sh"

# Debug mode
DEBUG="${DEBUG:-false}"

# ============================================================================
# Logging Functions
# ============================================================================

# Log files
FSWATCH_LOG="$LOG_DIR/fswatch.log"
MONITOR_LOG="$LOG_DIR/monitor.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR" "$WATCH_DIR" "$UPLOADED_DIR"

# Timestamp function
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Logging with timestamp
log() {
    local level="$1"
    local message="$2"
    local log_entry="[$(timestamp)] [$level] $message"
    
    # Write to monitor log
    echo "$log_entry" >> "$MONITOR_LOG"
    
    # Also print to stdout
    echo "$log_entry"
    
    # For errors, also print to stderr
    if [[ "$level" == "ERROR" ]]; then
        echo "$log_entry" >&2
    fi
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        log "DEBUG" "$1"
    fi
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARNING" "$1"
}

log_error() {
    log "ERROR" "$1"
}

# ============================================================================
# Load Configuration
# ============================================================================

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_debug "Loading configuration from $CONFIG_FILE"
        set -a
        source "$CONFIG_FILE"
        set +a
        log_info "Configuration loaded from $CONFIG_FILE"
    else
        log_warn "Configuration file not found at $CONFIG_FILE, using defaults"
    fi
}

# ============================================================================
# Validate Configuration
# ============================================================================

validate_config() {
    # Check watch directory exists
    if [[ ! -d "$WATCH_DIR" ]]; then
        log_error "Watch directory does not exist: $WATCH_DIR"
        mkdir -p "$WATCH_DIR"
    fi
    
    # Check upload worker script exists
    if [[ ! -f "$UPLOAD_WORKER" ]]; then
        log_error "Upload worker script not found: $UPLOAD_WORKER"
        exit 1
    fi
    
    # Check upload worker is executable
    if [[ ! -x "$UPLOAD_WORKER" ]]; then
        log_error "Upload worker script is not executable: $UPLOAD_WORKER"
        chmod +x "$UPLOAD_WORKER"
        log_info "Made upload worker executable"
    fi
    
    # Check inotifywait is available
    if ! command -v inotifywait &> /dev/null; then
        log_error "inotifywait is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Configuration validated successfully"
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup() {
    log_info "Monitor received shutdown signal, cleaning up..."
    log_info "Monitor stopped"
    exit 0
}

# ============================================================================
# Signal Handling
# ============================================================================

trap cleanup SIGINT SIGTERM SIGHUP

# ============================================================================
# Main Monitor Function
# ============================================================================

start_monitor() {
    log_info "=================================================="
    log_info "  Google Photos Sync Monitor Starting (Container)"
    log_info "=================================================="
    log_info "Watch directory: $WATCH_DIR"
    log_info "Upload worker: $UPLOAD_WORKER"
    log_info "Log directory: $LOG_DIR"
    log_info ""
    
    # Clear the fswatch log
    > "$FSWATCH_LOG"
    
    log_info "Starting inotifywait on $WATCH_DIR..."
    log_info "Press Ctrl+C to stop"
    log_info ""
    
    # Use inotifywait to monitor for new files
    # -m: monitor continuously
    # -r: recursive
    # -e: events to watch for
    # --format: output format
    # --timefmt: time format
    
    # We want to detect: file creation, file move into directory
    
    inotifywait \
        -m \
        -r \
        -e create \
        -e moved_to \
        -e close_write \
        --format '%w%f' \
        --timefmt '%Y-%m-%d %H:%M:%S' \
        "$WATCH_DIR" \
    | while read -r FILE_PATH; do
        # Log the detected file
        echo "[$(timestamp)] Detected file: $FILE_PATH" >> "$FSWATCH_LOG"
        
        # Only process regular files (not directories)
        if [ -f "$FILE_PATH" ]; then
            # Check if file is in the Watch directory
            if [[ "$FILE_PATH" == "$WATCH_DIR"* ]]; then
                echo "[$(timestamp)] Processing: $FILE_PATH" >> "$FSWATCH_LOG"
                
                if [ "$DEBUG" = "true" ]; then
                    echo "[$(timestamp)] Starting upload_worker for: $FILE_PATH" >> "$MONITOR_LOG"
                fi
                
                # Call upload worker in background
                "$UPLOAD_WORKER" "$FILE_PATH" &
            fi
        fi
    done
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    # Load configuration
    load_config
    
    # Validate configuration
    validate_config
    
    # Start the monitor
    start_monitor
}

# ============================================================================
# Run Main
# ============================================================================

main "$@"
