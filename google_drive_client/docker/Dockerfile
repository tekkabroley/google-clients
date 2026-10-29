# Google Drive Client - Dockerfile
# Multi-platform container for running on Windows, Mac, or Linux
#
# Usage:
#   docker build -t google-drive-client .
#   docker run -it --rm -v $(pwd)/credentials:/app/credentials google-drive-client

# Use a multi-platform base image with Python
FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Install Python dependencies from pyproject.toml
COPY pyproject.toml poetry.lock /app/
RUN pip install poetry && \
    poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-ansi --only main

# Copy the google_drive_client package
COPY google_drive_client /app/google_drive_client

# Set up entry point
COPY google_drive_client/docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create a volume for credentials
VOLUME /app/credentials

# Create a default .env file location
RUN mkdir -p /app/config

# Expose port for OAuth callback (used by authorize command)
EXPOSE 50200

# Set default command
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["--help"]
