# Google Photos Sync - Dockerfile
# Multi-platform container for running on Windows, Mac, or Linux
# 
# Usage:
#   docker build -t google-photos-sync .
#   docker run -it --rm -v ~/Photos_Sync:/app/data google-photos-sync

# Use a multi-platform base image with Python
FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
# For fswatch, we use inotify-tools on Linux (more reliable than fswatch)
# On macOS, users can use native fswatch with Docker desktop file mounting
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        inotify-tools \
        && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Install Python dependencies
COPY pyproject.toml poetry.lock /app/
RUN pip install poetry && \
    poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-ansi --only main

# Copy the google_photos_sync tool
COPY tools/google_photos_sync /app/google_photos_sync

# Copy entry point scripts
COPY tools/google_photos_sync/cli.py /app/cli.py
COPY tools/google_photos_sync/__init__.py /app/__init__.py

# Install rclone (cross-platform file sync tool)
ENV RCLONE_VERSION=1.68.1
RUN curl -sL https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-amd64.zip -o /tmp/rclone.zip && \
    unzip /tmp/rclone.zip -d /tmp && \
    mv /tmp/rclone-v${RCLONE_VERSION}-linux-amd64/rclone /usr/local/bin/rclone && \
    chmod +x /usr/local/bin/rclone && \
    rm -rf /tmp/rclone.zip /tmp/rclone-v${RCLONE_VERSION}-linux-amd64

# For ARM64 (Apple Silicon), install appropriate rclone
RUN if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then \
    curl -sL https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-arm64.zip -o /tmp/rclone.zip && \
    unzip /tmp/rclone.zip -d /tmp && \
    mv /tmp/rclone-v${RCLONE_VERSION}-linux-arm64/rclone /usr/local/bin/rclone && \
    chmod +x /usr/local/bin/rclone && \
    rm -rf /tmp/rclone.zip /tmp/rclone-v${RCLONE_VERSION}-linux-arm64; \
    fi

# Create data directory structure
RUN mkdir -p /app/data/Watch /app/data/Uploaded /app/data/Logs /app/data/config

# Set up environment variables for container
ENV WATCH_DIR=/app/data/Watch \
    UPLOADED_DIR=/app/data/Uploaded \
    LOG_DIR=/app/data/Logs \
    CONFIG_FILE=/app/data/config/config.env \
    RCLONE_CONFIG=/app/data/config/rclone.conf

# Create a wrapper script for the CLI that works in container
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create a version of upload_worker that uses inotifywait instead of fswatch
COPY docker/upload_worker_container.sh /app/google_photos_sync/upload_worker_container.sh
RUN chmod +x /app/google_photos_sync/upload_worker_container.sh

# Create a version of start_watch that works with inotifywait
COPY docker/start_watch_container.sh /app/google_photos_sync/start_watch_container.sh
RUN chmod +x /app/google_photos_sync/start_watch_container.sh

# Expose port for potential web interface (optional)
EXPOSE 8080

# Set default command
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["--help"]
