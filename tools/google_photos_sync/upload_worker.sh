#!/bin/bash

# Google Photos Sync - Upload Worker Script
# This script handles individual file uploads with debouncing to ensure
# files are completely written before attempting upload to Google Photos.

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Try to load config from Photos_Sync directory
CONFIG_FILE="${CONFIG_FILE:-$HOME/Photos_Sync/config.env}"

# Default values (can be overridden by config file or environment variables)
RCLONE_REMOTE="${RCLONE_REMOTE:-google_photos}"
RCLONE_ALBUM="${RCLONE_ALBUM:-AutoSync}"
WATCH_DIR="${WATCH_DIR:-$HOME/Photos_Sync/Watch}"
UPLOADED_DIR="${UPLOADED_DIR:-$HOME/Photos_Sync/Uploaded}"
LOG_DIR="${LOG_DIR:-$HOME/Photos_Sync/Logs}"
DEBOUNCE_SLEEP="${DEBOUNCE_SLEEP:-3}"
MAX_DEBOUNCE_ATTEMPTS="${MAX_DEBOUNCE_ATTEMPTS:-20}"
RCLONE_OPTIONS="${RCLONE_OPTIONS:---progress --fast-list}"

# Debug mode
DEBUG="${DEBUG:-false}"

# ============================================================================
# Logging Functions
# ============================================================================

# Log directory and file
LOG_FILE="$LOG_DIR/upload_worker.log"

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
    
    # Always write to log file
    echo "$log_entry" >> "$LOG_FILE"
    
    # Also print to stdout if debug or not DEBUG mode
    if [[ "$DEBUG" == "true" ]]; then
        echo "$log_entry"
    fi
    
    # For errors, always print to stderr
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
        # Export all variables from config file
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
    # Check required directories
    if [[ ! -d "$WATCH_DIR" ]]; then
        log_error "Watch directory does not exist: $WATCH_DIR"
        exit 1
    fi
    
    if [[ ! -d "$UPLOADED_DIR" ]]; then
        log_error "Uploaded directory does not exist: $UPLOADED_DIR"
        exit 1
    fi
    
    # Check rclone is available
    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed or not in PATH"
        exit 1
    fi
    
    # Verify rclone remote exists
    if ! rclone listremotes | grep -q "$RCLONE_REMOTE"; then
        log_error "rclone remote '$RCLONE_REMOTE' not configured"
        log_error "Available remotes:"
        rclone listremotes | while read -r remote; do
            log_error "  - $remote"
        done
        exit 1
    fi
    
    log_info "Configuration validated successfully"
}

# ============================================================================
# Debounce Function
# ============================================================================

# Wait for file size to stabilize
# This is critical for large files (60MB+ RAW) that may still be writing
debounce_file() {
    local file_path="$1"
    local max_attempts="$MAX_DEBOUNCE_ATTEMPTS"
    local sleep_seconds="$DEBOUNCE_SLEEP"
    local attempt=1
    
    log_info "Starting debounce for: $file_path"
    
    # Get initial file info
    if [[ ! -f "$file_path" ]]; then
        log_error "File does not exist: $file_path"
        return 1
    fi
    
    local prev_size=$(stat -f %z "$file_path" 2>/dev/null || stat -c %s "$file_path")
    local prev_mod_time=$(stat -f %m -t %Y "$file_path" 2>/dev/null || stat -c %Y "$file_path")
    
    log_debug "Initial size: $prev_size bytes, modified: $(date -r "$file_path" '+%Y-%m-%d %H:%M:%S')"
    
    while [[ $attempt -le $max_attempts ]]; do
        sleep "$sleep_seconds"
        
        # Check if file still exists (might have been deleted)
        if [[ ! -f "$file_path" ]]; then
            log_warn "File disappeared during debounce: $file_path"
            return 1
        fi
        
        # Get current file info
        local current_size=$(stat -f %z "$file_path" 2>/dev/null || stat -c %s "$file_path")
        local current_mod_time=$(stat -f %m -t %Y "$file_path" 2>/dev/null || stat -c %Y "$file_path")
        
        log_debug "Attempt $attempt: size=$current_size, prev=$prev_size"
        
        # Check if size has stabilized
        if [[ "$current_size" == "$prev_size" ]]; then
            # Size is stable, check modification time too for extra safety
            if [[ "$current_mod_time" == "$prev_mod_time" ]]; then
                log_info "File size stabilized at $current_size bytes after $attempt attempt(s)"
                return 0
            fi
        fi
        
        # Update previous values
        prev_size="$current_size"
        prev_mod_time="$current_mod_time"
        attempt=$((attempt + 1))
    done
    
    log_error "File size did not stabilize after $max_attempts attempts: $file_path"
    return 1
}

# ============================================================================
# Upload Function
# ============================================================================

upload_to_google_photos() {
    local file_path="$1"
    local file_name
    file_name=$(basename "$file_path")
    
    local remote_path="${RCLONE_REMOTE}:${RCLONE_ALBUM}/${file_name}"
    
    log_info "Uploading $file_name to $remote_path"
    
    # Execute rclone copy
    # --progress: Show progress
    # --fast-list: Use faster directory listing
    # --retries: Number of retries
    # --retries-sleep: Time to sleep between retries
    local rclone_cmd="rclone copy \"$file_path\" \"$remote_path\" $RCLONE_OPTIONS --retries 3 --retries-sleep 5s"
    
    log_debug "Executing: $rclone_cmd"
    
    # Capture output and exit code
    local upload_output
    local upload_exit_code
    
    upload_output=$(eval "$rclone_cmd" 2>&1) || upload_exit_code=$?
    
    if [[ $upload_exit_code -eq 0 ]]; then
        log_info "Upload successful for $file_name"
        echo "$upload_output" | while IFS= read -r line; do
            log_debug "rclone: $line"
        done
        return 0
    else
        log_error "Upload failed for $file_name (exit code: $upload_exit_code)"
        echo "$upload_output" | while IFS= read -r line; do
            log_error "rclone: $line"
        done
        return 1
    fi
}

# ============================================================================
# Archive Function
# ============================================================================

archive_file() {
    local file_path="$1"
    local file_name
    file_name=$(basename "$file_path")
    local dest_path="$UPLOADED_DIR/$file_name"
    
    log_info "Moving $file_name to $dest_path"
    
    # Use mv which preserves file metadata
    if mv "$file_path" "$dest_path"; then
        log_info "Successfully archived $file_name"
        return 0
    else
        log_error "Failed to move $file_path to $dest_path"
        return 1
    fi
}

# ============================================================================
# Main Processing Function
# ============================================================================

process_file() {
    local file_path="$1"
    local file_name
    file_name=$(basename "$file_path")
    
    log_info "========================================"
    log_info "Processing file: $file_name"
    log_info "========================================"
    
    # Step 1: Debounce - wait for file to stabilize
    if ! debounce_file "$file_path"; then
        log_error "Debounce failed for $file_name, skipping"
        return 1
    fi
    
    # Step 2: Upload to Google Photos
    if ! upload_to_google_photos "$file_path"; then
        log_error "Upload failed for $file_name, file remains in Watch/"
        return 1
    fi
    
    # Step 3: Archive the file
    if ! archive_file "$file_path"; then
        log_error "Archive failed for $file_name, but upload was successful"
        # File might be in an inconsistent state, try to handle it
        if [[ -f "$file_path" ]]; then
            log_warn "File still exists at $file_path after failed archive"
        fi
        return 1
    fi
    
    log_info "✓ Successfully processed $file_name"
    return 0
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    # Load configuration
    load_config
    
    # Validate configuration
    validate_config
    
    # Check if file path is provided
    if [[ $# -lt 1 ]]; then
        log_error "Usage: $0 <file_path>"
        log_error "No file specified"
        exit 1
    fi
    
    local file_path="$1"
    
    # Resolve to absolute path
    if [[ "$file_path" != /* ]]; then
        file_path="$(pwd)/$file_path"
    fi
    
    # Verify file exists
    if [[ ! -f "$file_path" ]]; then
        log_error "File does not exist: $file_path"
        exit 1
    fi
    
    # Process the file
    if process_file "$file_path"; then
        exit 0
    else
        exit 1
    fi
}

# ============================================================================
# Signal Handling
# ============================================================================

# Trap signals for clean exit
trap 'log_info "Upload worker interrupted by signal"; exit 1' SIGINT SIGTERM

# ============================================================================
# Run Main
# ============================================================================

main "$@"
