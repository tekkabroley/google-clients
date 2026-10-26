#!/bin/bash

# Google Photos Sync - File Watch Monitor
# This script uses fswatch to monitor the Watch directory and trigger
# upload_worker.sh for each new file detected.

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Try to load config from Photos_Sync directory
CONFIG_FILE="${CONFIG_FILE:-$HOME/Photos_Sync/config.env}"

# Default values (can be overridden by config file or environment variables)
WATCH_DIR="${WATCH_DIR:-$HOME/Photos_Sync/Watch}"
LOG_DIR="${LOG_DIR:-$HOME/Photos_Sync/Logs}"

# Script directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPLOAD_WORKER="$SCRIPT_DIR/upload_worker.sh"

# Debug mode
DEBUG="${DEBUG:-false}"

# ============================================================================
# Logging Functions
# ============================================================================

# Log files
FSWATCH_LOG="$LOG_DIR/fswatch.log"
MONITOR_LOG="$LOG_DIR/monitor.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

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
        exit 1
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
    
    # Check fswatch is available
    if ! command -v fswatch &> /dev/null; then
        log_error "fswatch is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Configuration validated successfully"
}

# ============================================================================
# Cleanup Function
# ============================================================================

cleanup() {
    log_info "Monitor received shutdown signal, cleaning up..."
    # Any cleanup code here
    log_info "Monitor stopped"
    exit 0
}

# ============================================================================
# Signal Handling
# ============================================================================

# Trap signals for clean exit
trap cleanup SIGINT SIGTERM SIGHUP

# ============================================================================
# Main Monitor Function
# ============================================================================

start_monitor() {
    log_info "=================================================="
    log_info "  Google Photos Sync Monitor Starting"
    log_info "=================================================="
    log_info "Watch directory: $WATCH_DIR"
    log_info "Upload worker: $UPLOAD_WORKER"
    log_info "Log directory: $LOG_DIR"
    log_info ""
    
    # fswatch options:
    # -0: Use null byte as separator (for xargs -0)
    # -l: Latency in seconds (reduce CPU usage)
    # -r: Recursive monitoring
    # -x: Exclude directories (we only want files)
    # .*: Only report when files are created (not modified, deleted, etc.)
    # --event-flag 0x4: Only report file creation events (FSEvents kFSEventStreamEventFlagItemCreated)
    
    # Note: On macOS, fswatch uses FSEvents which may have some latency
    # The -l option helps reduce CPU usage
    
    log_info "Starting fswatch on $WATCH_DIR..."
    log_info "Press Ctrl+C to stop"
    log_info ""
    
    # Use a latency of 0.5 seconds to reduce CPU usage
    # This doesn't affect debouncing, which happens in upload_worker.sh
    local fswatch_latency="0.5"
    
    # Build fswatch command
    # We monitor for: Created, Renamed (moved into directory)
    # Exclude: directories, .DS_Store files
    
    # fswatch events to monitor:
    # Platform events: Created, Renamed
    # We use --event with specific flags
    
    # On macOS, use -x to exclude directories
    # Pattern: only files with extensions we care about
    
    # Use null byte separator with xargs for handling filenames with spaces
    # fswatch -0 prints null-separated file paths
    # xargs -0 reads null-separated input
    
    # We want to detect:
    # - New files created in the directory
    # - Files moved into the directory
    
    # fswatch command with detailed event filtering
    log_debug "fswatch command: fswatch -0 -l $fswatch_latency -x -r --event Created --event Renamed --event MovedTo --exclude '.DS_Store' --exclude '.*' "$WATCH_DIR"
    
    # Clear the fswatch log
    > "$FSWATCH_LOG"
    
    # Start fswatch and pipe to xargs which calls upload_worker for each file
    fswatch \
        -0 \
        -l "$fswatch_latency" \
        -x \
        -r \
        --event Created \
        --event Renamed \
        --event MovedTo \
        --exclude '.DS_Store' \
        --exclude '^\.' \
        "$WATCH_DIR" \
    | xargs -0 -n 1 -I {} bash -c '
        FILE_PATH="{}"
        # Log the detected file
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Detected file: $FILE_PATH" >> "'$FSWATCH_LOG'"
        
        # Only process regular files (not directories)
        if [ -f "$FILE_PATH" ]; then
            # Check if file is in the Watch directory (fswatch might report subdirectories)
            if [[ "$FILE_PATH" == "'$WATCH_DIR'"/* ]]; then
                echo "[$(date "+%Y-%m-%d %H:%M:%S")] Processing: $FILE_PATH" >> "'$FSWATCH_LOG'"
                
                # Call upload worker
                if [ "$DEBUG" = "true" ]; then
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Starting upload_worker for: $FILE_PATH" >> "'$MONITOR_LOG'"
                fi
                
                "$UPLOAD_WORKER" "$FILE_PATH" &
            fi
        fi
    ' &
    
    # Wait for the background fswatch process
    local fswatch_pid=$!
    wait $fswatch_pid
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
