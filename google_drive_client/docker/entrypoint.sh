#!/bin/bash

# Google Drive Client - Docker Entry Point
# This script adapts the CLI to work in a container environment

set -euo pipefail

# Create directories if they don't exist
mkdir -p /app/credentials /app/config /app/data

# Check if GOOGLE_APPLICATION_CREDENTIALS is set
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    # If it's a file path, copy it to the expected location
    if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        cp "$GOOGLE_APPLICATION_CREDENTIALS" /app/credentials/credentials.json
        export GOOGLE_APPLICATION_CREDENTIALS=/app/credentials/credentials.json
    fi
fi

# Check if .env file is mounted
if [ -f /app/config/.env ]; then
    echo "Loading environment from /app/config/.env"
    set -a
    source /app/config/.env
    set +a
fi

# Check if credentials are mounted at /app/credentials
CREDENTIALS_PATH="/app/credentials"
if [ -d "$CREDENTIALS_PATH" ]; then
    # Check for service account credentials
    if [ -f "$CREDENTIALS_PATH/service-account.json" ]; then
        export GOOGLE_APPLICATION_CREDENTIALS="$CREDENTIALS_PATH/service-account.json"
    fi
    
    # Check for user credentials
    if [ -f "$CREDENTIALS_PATH/credentials.json" ]; then
        # Set environment variable for the Python app
        export GOOGLE_CLIENT_CREDENTIALS="file://$CREDENTIALS_PATH/credentials.json"
    fi
    
    # Check for token
    if [ -f "$CREDENTIALS_PATH/token.json" ]; then
        export GOOGLE_TOKEN_PATH="$CREDENTIALS_PATH/token.json"
    fi
fi

# If no credentials are found, provide helpful message
if [ ! -f "$CREDENTIALS_PATH/credentials.json" ] && [ ! -f "$CREDENTIALS_PATH/service-account.json" ]; then
    echo ""
    echo "=========================================="
    echo "  Google Drive Client - Credentials Needed"
    echo "=========================================="
    echo ""
    echo "To use this container, you need to provide Google API credentials."
    echo ""
    echo "Option 1: Mount your credentials file"
    echo "  docker run -v /path/to/credentials.json:/app/credentials/credentials.json ..."
    echo ""
    echo "Option 2: Mount a directory with credentials"
    echo "  docker run -v /path/to/creds:/app/credentials ..."
    echo ""
    echo "Option 3: Set environment variable"
    echo "  docker run -e GOOGLE_CLIENT_CREDENTIALS=\"file:///app/credentials/creds.json\" ..."
    echo ""
    echo "For user credentials (OAuth), run the authorize command first:"
    echo "  docker run -it -p 50200:50200 google-drive-client authorize <project-id> <client-id> <client-secret>"
    echo ""
fi

# Run the CLI
exec python -m google_drive_client.cli "$@"
