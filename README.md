# Google Clients

A collection of Google API clients and tools for various Google services.

## Overview

This repository contains Python-based clients for Google APIs, along with automation tools for common workflows.

## Packages

### 1. Google Drive Client (`google_drive_client/`)

A comprehensive Python client for Google Drive with CLI support.

**Features:**
- Create, list, and manage files and folders
- Share files with users or domains
- Download files with export support for Google Workspace formats
- OAuth2 authentication

**Usage:**
```bash
# Install the package
pip install -e .

# Use the CLI
gdrive-cli --help

# Example: List files in a folder
gdrive-cli list-files FOLDER_ID

# Example: Create a new sheet
gdrive-cli create "My New Sheet" FOLDER_ID
```

### 2. Google Photos Sync (`tools/google_photos_sync/`)

A lightweight, background-capable automation system that watches a local directory on macOS, waits for incoming image files to completely finish writing, and uploads them to Google Photos using `rclone`.

**Features:**
- Real-time file monitoring with `fswatch`
- Intelligent debouncing for large files (60MB+ RAW files)
- Automatic upload to Google Photos via `rclone`
- Archive management (moves uploaded files to prevent duplicates)
- Comprehensive logging
- Optional launchd service for auto-start on login
- Python CLI wrapper for integration

**Prerequisites:**
- macOS
- Homebrew (for installing rclone and fswatch)
- Google account with Google Photos API access

**Quick Start:**

```bash
# Install system dependencies (rclone, fswatch)
./tools/google_photos_sync/setup.sh

# Configure rclone for Google Photos
rclone config

# Edit configuration
nano ~/Photos_Sync/config.env

# Start the monitor
./tools/google_photos_sync/start_watch.sh

# Or use the Python CLI
pip install -e .
gphotos-sync start
```

**Python CLI Commands:**
```bash
gphotos-sync setup              # Install dependencies
gphotos-sync start               # Start the monitor
gphotos-sync stop                # Stop the monitor
gphotos-sync upload FILE_PATH    # Upload a single file
gphotos-sync status              # Check system status
gphotos-sync logs                # View log files
gphotos-sync install-service     # Install as launchd service
gphotos-sync uninstall-service   # Uninstall launchd service
```

**Directory Structure:**
```
~/Photos_Sync/
├── Watch/          # Monitored directory for incoming files
├── Uploaded/       # Archive for successfully uploaded files
└── Logs/           # Log files for debugging
```

**launchd Service:**

For automatic startup on login:

```bash
# Install the service
gphotos-sync install-service

# Or manually:
cp tools/google_photos_sync/com.local.google-photos-sync.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.local.google-photos-sync.plist
launchctl start com.local.google-photos-sync
```

## Installation

### Development Setup

```bash
# Clone the repository
git clone https://github.com/alexbroley/google-clients.git
cd google-clients

# Install dependencies with Poetry
poetry install

# Or with pip
pip install -e .
```

### System Dependencies (for Google Photos Sync)

On macOS, install the required system tools:

```bash
# Using Homebrew
brew install rclone fswatch

# Configure rclone for Google Photos
rclone config
```

## Configuration

### Google Drive Client

1. Create a Google Cloud project
2. Enable the Google Drive API
3. Create OAuth2 credentials (Desktop app type)
4. Save credentials as `credentials.json`
5. Run `gdrive-cli authorize` to authenticate

### Google Photos Sync

1. Run `./tools/google_photos_sync/setup.sh`
2. Configure rclone: `rclone config`
3. Edit `~/Photos_Sync/config.env` to set:
   - `RCLONE_REMOTE`: Your rclone remote name
   - `RCLONE_ALBUM`: Target Google Photos album

## Project Structure

```
google-clients/
├── google_drive_client/
│   ├── __init__.py
│   ├── cli.py           # Typer-based CLI
│   ├── client.py        # DriveClient class
│   └── credentials.py   # Authentication handling
├── tools/
│   └── google_photos_sync/
│       ├── __init__.py       # Python interface
│       ├── cli.py           # Python CLI
│       ├── README.md        # Documentation
│       ├── setup.sh         # Dependency setup
│       ├── start_watch.sh    # Monitor script
│       ├── upload_worker.sh  # File processing script
│       └── com.local.google-photos-sync.plist  # launchd config
├── pyproject.toml
└── README.md
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests (if available)
5. Submit a pull request

## License

This project is private and proprietary. Do not distribute without permission.

## Support

For issues or questions, please open a GitHub issue.
