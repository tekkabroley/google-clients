# Google Photos Sync Tool

A lightweight, background-capable automation system that watches a local directory, waits for incoming image files to completely finish writing, and uploads them to Google Photos using `rclone`.

## Platforms Supported

- **macOS**: Native installation with Homebrew (original implementation)
- **Windows**: via Docker container
- **Linux**: via Docker container

## Quick Start (Docker - Recommended for Windows/Linux)

For cross-platform support, use the Docker container:

```bash
# Build and run with docker-compose
cd /path/to/google-clients
docker-compose -f tools/google_photos_sync/docker-compose.yml up -d
```

**Windows Users:** For the easiest setup, simply double-click `tools/google_photos_sync/start_windows.bat` - it handles everything automatically!

See the [Docker documentation](docker/README.md) for complete setup instructions.

---

## Quick Start (macOS Native)

### System Dependencies (macOS)

This tool requires the following system-level dependencies, which must be installed via Homebrew:

```bash
# Install rclone (for Google Photos uploads)
brew install rclone

# Install fswatch (for file system monitoring)
brew install fswatch
```

### Google Photos Configuration for rclone

1. **Set up rclone remote for Google Photos:**

```bash
# Run rclone config to create a new remote
rclone config
```

2. **Follow the interactive prompts:**
   - Select `n` for new remote
   - Enter a name (e.g., `google_photos`)
   - Select `google photos` as the storage type
   - Follow the OAuth2 authentication flow in your browser
   - When prompted for "Edit advanced config?", select `n`
   - When prompted for "Use auto config?", select `y`

3. **Verify your remote:**

```bash
# List existing remotes
rclone listremotes

# Test the connection (list albums)
rclone lsd google_photos:
```

4. **Create or identify your target album:**
   - Google Photos albums will appear as directories
   - Note the album path (e.g., `google_photos:AutoSync`)

## Directory Structure

The tool uses the following directory structure (created automatically on first run):

```
~/Photos_Sync/
├── Watch/          # Monitored directory for incoming files
├── Uploaded/       # Archive for successfully uploaded files
└── Logs/           # Log files for debugging
```

## Quick Start

### 1. Set up dependencies (one-time)

```bash
# Install system dependencies
./tools/google_photos_sync/setup.sh
```

This will:
- Install rclone and fswatch via Homebrew
- Guide you through rclone Google Photos configuration
- Create the required directory structure

### 2. Configure your settings

Edit the configuration file:

```bash
nano ~/Photos_Sync/config.env
```

Set your rclone remote and target album:

```bash
RCLONE_REMOTE="google_photos"
RCLONE_ALBUM="AutoSync"
WATCH_DIR="$HOME/Photos_Sync/Watch"
UPLOADED_DIR="$HOME/Photos_Sync/Uploaded"
LOG_DIR="$HOME/Photos_Sync/Logs"
```

### 3. Start the monitor

**Option A: Manual start (terminal-based)**

```bash
./tools/google_photos_sync/start_watch.sh
```

**Option B: Background service (recommended)**

```bash
# Load the launchd plist
cp tools/google_photos_sync/com.local.google-photos-sync.plist ~/Library/LaunchAgents/

# Load and start the service
launchctl load ~/Library/LaunchAgents/com.local.google-photos-sync.plist
launchctl start com.local.google-photos-sync
```

## Usage

### Start monitoring

```bash
./start_watch.sh
```

This will:
- Start fswatch monitoring the Watch directory
- Automatically process new files through the debounce and upload pipeline
- Log all activity to ~/Photos_Sync/Logs/

### Stop monitoring

If running in terminal: Press `Ctrl+C`

If running as launchd service:

```bash
launchctl unload ~/Library/LaunchAgents/com.local.google-photos-sync.plist
```

### Manual upload (single file)

```bash
./upload_worker.sh /path/to/your/file.jpg
```

## How It Works

1. **File Detection**: `fswatch` monitors the Watch directory for new files
2. **Debouncing**: When a new file is detected, `upload_worker.sh` checks the file size repeatedly with 3-second intervals until it stabilizes (ensuring complete file transfer from cameras/SD cards)
3. **Upload**: Once stable, the file is uploaded to Google Photos using `rclone copy`
4. **Cleanup**: On successful upload (exit code 0), the file is moved to Uploaded/; on failure, it remains in Watch/ and the error is logged

## Logs

All operations are logged to:
- `~/Photos_Sync/Logs/upload_worker.log` - Upload operations and debouncing
- `~/Photos_Sync/Logs/fswatch.log` - File system monitoring events

## Troubleshooting

### Common Issues

**1. rclone authentication failures**
```bash
# Re-authenticate
rclone config edit
# Or revoke and re-authenticate
rclone config disconnect google_photos:
```

**2. fswatch not detecting files**
- Verify fswatch is installed: `which fswatch`
- Check directory permissions: `ls -la ~/Photos_Sync/`

**3. Files not moving to Uploaded after successful upload**
- Check rclone exit code in logs
- Verify write permissions on Uploaded directory

**4. Large files (60MB+ RAW) not uploading**
- The debounce loop handles this automatically
- Check that file size stabilizes in logs

### Debug Mode

To enable verbose logging:

```bash
# Set DEBUG environment variable
DEBUG=true ./start_watch.sh
```

Or edit the scripts and set `DEBUG=true` at the top.

## Uninstall

```bash
# Stop and remove launchd service
launchctl unload ~/Library/LaunchAgents/com.local.google-photos-sync.plist
rm ~/Library/LaunchAgents/com.local.google-photos-sync.plist

# Remove directories (optional - will remove all synced files)
rm -rf ~/Photos_Sync/
```

## Files in This Package

- `setup.sh` - Dependency installation and initial setup (macOS)
- `start_watch.sh` - Main monitor script with fswatch (macOS)
- `upload_worker.sh` - File processing with debouncing and upload (macOS)
- `com.local.google-photos-sync.plist` - launchd configuration (macOS)
- `docker/` - Docker container configuration for cross-platform support
  - `Dockerfile` - Container image definition
  - `docker-compose.yml` - Docker Compose configuration
  - `README.md` - Docker-specific documentation
- `README.md` - This file

## Docker Support

For **Windows, macOS, and Linux** users, or anyone who prefers containerized deployments, Docker support is provided:

- Full containerization with all dependencies (rclone, inotify-tools, Python)
- Cross-platform file monitoring using inotifywait
- Easy deployment with docker-compose
- Complete isolation from host system

---

### 🪟 Windows 11/10 Instructions

#### Quick Start (Recommended)

Simply **double-click** the batch file:
```
tools\google_photos_sync\start_windows.bat
```

This automatically:
- Checks Docker Desktop is installed and running
- Verifies WSL 2 is available
- Builds the Docker image
- Starts the container
- Guides you through rclone configuration
- Creates all necessary directories
- Opens the config file for editing

#### Manual Setup

If you prefer command line:

```cmd
cd C:\path\to\google-clients\tools\google_photos_sync
start_windows.bat
```

#### After Setup

1. **Add photos**: Copy files to `tools\google_photos_sync\Photos_Sync\Watch\`
2. **View logs**: `docker logs -f google-photos-sync`
3. **Stop service**: `docker stop google-photos-sync`
4. **Restart**: Use `docker\run_windows.bat` or `docker start google-photos-sync`

#### Prerequisites for Windows

- [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) installed
- WSL 2 enabled (Docker Desktop will guide you through this)
- Docker Desktop running (whale icon in system tray)

---

### 🍎 macOS Instructions (Docker)

#### Option A: Using docker-compose (Recommended)

```bash
# Navigate to project directory
cd /path/to/google-clients

# Build and start the container
docker-compose -f tools/google_photos_sync/docker-compose.yml up -d

# View logs
docker-compose -f tools/google_photos_sync/docker-compose.yml logs -f
```

#### Option B: Using Docker Run

```bash
# Build the image
docker build -t google-photos-sync -f tools/google_photos_sync/docker/Dockerfile .

# Run the container
docker run -d \
  --name google-photos-sync \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync start

# View logs
docker logs -f google-photos-sync
```

#### Configure rclone

After starting the container:

```bash
# Run interactive configuration
docker exec -it google-photos-sync rclone config --config=/app/data/config/rclone.conf
```

Follow the prompts to authenticate with Google Photos.

#### Edit Configuration

```bash
# Edit the config file on your Mac
nano Photos_Sync/config/config.env

# Or open in TextEdit
open Photos_Sync/config/config.env
```

Set these values:
```ini
RCLONE_REMOTE="google_photos"
RCLONE_ALBUM="AutoSync"
```

#### Add Photos to Sync

Copy files to:
```bash
cp /path/to/your/photo.jpg Photos_Sync/Watch/
```

Files will automatically:
1. Be detected by the container
2. Wait for complete write (debouncing)
3. Upload to Google Photos
4. Move to `Photos_Sync/Uploaded/` on success

#### Useful Commands

```bash
# Stop container
docker stop google-photos-sync

# Start container
docker start google-photos-sync

# Restart container
docker restart google-photos-sync

# Check status
docker exec google-photos-sync google-photos-sync status

# Open shell in container
docker exec -it google-photos-sync bash

# Upload single file
docker exec google-photos-sync google-photos-sync upload /path/in/container/file.jpg

# View container IP
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' google-photos-sync
```

#### Prerequisites for macOS

- Docker Desktop for Mac installed and running
- No additional dependencies needed (everything runs in the container)

---

### 🐧 Linux Instructions (Docker)

Same as macOS Docker instructions above. Use the same docker-compose or docker run commands.

---

### ❓ Choosing: Native vs Docker on macOS

| Feature | Native (macOS) | Docker (macOS) |
|---------|---------------|----------------|
| Performance | ⭐⭐⭐⭐⭐ Native speed | ⭐⭐⭐⭐ Slight overhead |
| Dependencies | Requires Homebrew, rclone, fswatch | All included in container |
| Setup Complexity | Medium (multiple steps) | Easy (single command) |
| File Monitoring | fswatch (native macOS) | inotifywait (Linux in container) |
| System Integration | Direct access to files | Volume mounted |
| Recommended For | Developers, power users | Beginners, cross-platform users |

For most macOS users, the **native installation** is recommended for best performance. Use Docker if you:
- Want complete isolation
- Need to match production environments
- Prefer containerized deployments
- Want to test on multiple platforms

See [docker/README.md](docker/README.md) for complete Docker setup instructions.
