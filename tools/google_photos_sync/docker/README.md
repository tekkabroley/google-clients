# Google Photos Sync - Docker Container

Run the Google Photos Sync tool on **Windows, macOS, or Linux** using Docker containers. This eliminates the need for platform-specific dependencies like Homebrew and fswatch.

## Windows Users - Quick Start with Batch Files

For the easiest setup on **Windows 11/10**, simply double-click:
- `tools/google_photos_sync/start_windows.bat` - Complete setup (build + run + configure)
- `tools/google_photos_sync/docker/run_windows.bat` - Quick start (after initial setup)

These batch files automatically:
- Check Docker Desktop is installed and running
- Verify WSL 2 is available
- Build the Docker image
- Start the container
- Guide you through rclone configuration
- Create all necessary directories

## Quick Start

### 1. Build the Docker Image

```bash
# Navigate to your project directory
cd /path/to/google-clients

# Build the Docker image
docker build -t google-photos-sync -f tools/google_photos_sync/docker/Dockerfile .
```

**Alternative: Use docker-compose (recommended)**

```bash
docker-compose -f tools/google_photos_sync/docker-compose.yml build
```

### 2. Configure rclone

Before running, you need to configure rclone with your Google Photos credentials:

```bash
# Run an interactive shell in the container
docker run -it --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync bash

# Inside the container, run rclone config
rclone config --config=/app/data/config/rclone.conf
```

Follow the prompts to:
1. Create a new remote (select `n`)
2. Name it (e.g., `google_photos`)
3. Select `google photos` as the storage type
4. Complete the OAuth2 authentication in your browser
5. Select `n` for advanced config
6. Select `y` for auto config

**OR: Use your existing rclone config**

```bash
# Mount your existing config file
docker run -it --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  -v ~/.config/rclone/rclone.conf:/app/data/config/rclone.conf \
  google-photos-sync start
```

### 3. Configure the Sync Tool

Edit the configuration file at `Photos_Sync/config/config.env`:

```bash
# On your host machine
nano Photos_Sync/config/config.env
```

Update the settings:

```ini
# Rclone remote name
RCLONE_REMOTE="google_photos"

# Target album in Google Photos
RCLONE_ALBUM="AutoSync"

# Directory paths (these map to /app/data in the container)
WATCH_DIR="/app/data/Watch"
UPLOADED_DIR="/app/data/Uploaded"
LOG_DIR="/app/data/Logs"

# Debounce settings (for large files)
DEBOUNCE_SLEEP=3
MAX_DEBOUNCE_ATTEMPTS=20
```

### 4. Run the Monitor

**Option A: Using docker-compose (recommended)**

```bash
# Start the container with the monitor
docker-compose -f tools/google_photos_sync/docker-compose.yml up -d

# View logs
docker-compose -f tools/google_photos_sync/docker-compose.yml logs -f
```

**Option B: Using docker run directly**

```bash
# Run the monitor in detached mode
docker run -d \
  --name google-photos-sync \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync start

# View logs
docker logs -f google-photos-sync
```

**Option C: Run in foreground (for debugging)**

```bash
docker run -it --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync start
```

### 5. Add Files to Sync

Drop files into the `Photos_Sync/Watch` directory on your host machine:

```bash
# Copy files to the watch directory
cp /path/to/your/photo.jpg Photos_Sync/Watch/
```

The container will automatically:
1. Detect the new file
2. Wait for the file to completely finish writing (debouncing)
3. Upload to Google Photos
4. Move the file to `Photos_Sync/Uploaded`

## Usage Commands

### Start the Monitor

```bash
# Using docker-compose
docker-compose -f tools/google_photos_sync/docker-compose.yml up -d

# Using docker
docker run -d --name google-photos-sync \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync start
```

### Stop the Monitor

```bash
# Using docker-compose
docker-compose -f tools/google_photos_sync/docker-compose.yml down

# Using docker
docker stop google-photos-sync
docker rm google-photos-sync
```

### Upload a Single File

```bash
docker run --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  -v /path/to/file.jpg:/tmp/file.jpg \
  google-photos-sync upload /tmp/file.jpg
```

### Check Status

```bash
docker run --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync status
```

### View Logs

```bash
# Using docker-compose
docker-compose -f tools/google_photos_sync/docker-compose.yml logs -f

# Using docker
docker logs -f google-photos-sync

# Or check the log files directly
cat Photos_Sync/Logs/upload_worker.log
cat Photos_Sync/Logs/fswatch.log
```

### Run Setup

```bash
docker run -it --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync setup
```

## Platform-Specific Notes

### Windows

On Windows, use PowerShell or CMD:

```powershell
# Build the image
docker build -t google-photos-sync -f toolsfgoogle_photos_syncfdockerfDockerfile .

# Run with volume mount
docker run -d --name google-photos-sync ^
  -v ${PWD}/Photos_Sync:/app/data ^
  google-photos-sync start
```

**Note:** Windows file system monitoring uses inotifywait through the Linux container, which works with Docker Desktop's file sharing.

### macOS

On macOS, you can use either Docker Desktop or the native Docker:

```bash
# Build
docker build -t google-photos-sync -f tools/google_photos_sync/docker/Dockerfile .

# Run
docker run -d --name google-photos-sync \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync start
```

### Linux

On Linux, the container works natively:

```bash
# Build
docker build -t google-photos-sync -f tools/google_photos_sync/docker/Dockerfile .

# Run
docker run -d --name google-photos-sync \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync start
```

## Advanced Configuration

### Custom Directory Structure

Mount custom directories to the container:

```bash
docker run -d \
  --name google-photos-sync \
  -v /path/to/watch:/app/data/Watch \
  -v /path/to/uploaded:/app/data/Uploaded \
  -v /path/to/logs:/app/data/Logs \
  -v /path/to/config:/app/data/config \
  google-photos-sync start
```

### Environment Variables

Override configuration with environment variables:

```bash
docker run -d \
  --name google-photos-sync \
  -v $(pwd)/Photos_Sync:/app/data \
  -e RCLONE_REMOTE=my_remote \
  -e RCLONE_ALBUM=VacationPhotos \
  -e DEBUG=true \
  google-photos-sync start
```

### Multiple Albums

To sync to different albums, run multiple containers with different configurations:

```bash
# Container 1 - Album 1
docker run -d \
  --name google-photos-sync-1 \
  -v $(pwd)/Photos_Sync_1:/app/data \
  -e RCLONE_ALBUM=Album1 \
  google-photos-sync start

# Container 2 - Album 2
docker run -d \
  --name google-photos-sync-2 \
  -v $(pwd)/Photos_Sync_2:/app/data \
  -e RCLONE_ALBUM=Album2 \
  google-photos-sync start
```

## Troubleshooting

### Files Not Being Detected

1. **Check volume mounts**: Ensure your host directory is correctly mounted to `/app/data/Watch`
2. **Check permissions**: The container needs read/write access to the mounted directory
3. **Check inotifywait**: Ensure the container has inotifywait installed

```bash
# Test if inotifywait works in the container
docker run -it --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync bash -c "inotifywait -m /app/data/Watch"
```

### Authentication Issues

1. **Verify rclone config**: Ensure your rclone.conf is in the correct location
2. **Check token expiration**: Google OAuth tokens may expire

```bash
# Re-authenticate
docker run -it --rm \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync bash -c "rclone config --config=/app/data/config/rclone.conf"
```

### Permission Denied Errors

Ensure the container has proper permissions:

```bash
# Check directory permissions
ls -la Photos_Sync/

# Fix permissions if needed
chmod -R 777 Photos_Sync/
```

Or run the container with the current user's permissions:

```bash
docker run -d \
  --name google-photos-sync \
  -u $(id -u):$(id -g) \
  -v $(pwd)/Photos_Sync:/app/data \
  google-photos-sync start
```

### Large Files (60MB+ RAW)

The debounce mechanism handles large files automatically. You can adjust the settings:

```bash
# Edit config.env and increase these values
DEBOUNCE_SLEEP=5    # Wait longer between checks
MAX_DEBOUNCE_ATTEMPTS=30  # More attempts
```

## Performance Considerations

1. **Volume Performance**: On macOS/Windows, Docker volume mounts can be slow. For best performance:
   - Use named volumes for frequently accessed files
   - Consider using Docker Desktop's file sharing optimizations

2. **CPU Usage**: The inotifywait-based monitoring is lightweight, but you can reduce it further:

```bash
# In docker-compose.yml, add CPU limits
services:
  google-photos-sync:
    cpus: 0.5
```

3. **Memory**: The container uses minimal memory. For very large file transfers:

```bash
# In docker-compose.yml, add memory limits
services:
  google-photos-sync:
    mem_limit: 256m
```

## Updating

To update to the latest version:

```bash
# Pull the latest code
git pull

# Rebuild the image
docker-compose -f tools/google_photos_sync/docker-compose.yml build --no-cache

# Restart the container
docker-compose -f tools/google_photos_sync/docker-compose.yml up -d
```

## Uninstalling

```bash
# Stop and remove the container
docker-compose -f tools/google_photos_sync/docker-compose.yml down

# Remove the Docker image
docker rmi google-photos-sync

# Remove data (optional - this will delete all synced files)
rm -rf Photos_Sync/
```

## Development

To modify the Docker configuration:

1. Edit files in `tools/google_photos_sync/docker/`
2. Rebuild the image with `--no-cache` to ensure changes are picked up:

```bash
docker-compose -f tools/google_photos_sync/docker-compose.yml build --no-cache
```

## Architecture

The Docker container includes:

- **Base**: Python 3.11 slim
- **Dependencies**: rclone, inotify-tools, Python packages from pyproject.toml
- **File Monitoring**: Uses `inotifywait` (Linux) instead of `fswatch` (macOS) for cross-platform compatibility
- **Data Persistence**: All data is stored in mounted volumes for persistence across container restarts

## Comparison: Native vs Docker

| Feature | Native (macOS) | Docker (Cross-Platform) |
|---------|---------------|-------------------------|
| File Monitoring | fswatch | inotifywait |
| Dependencies | Homebrew | Containerized |
| Platform Support | macOS only | Windows, macOS, Linux |
| Installation | Requires Homebrew | Requires Docker |
| Performance | Native speed | Slight overhead |
| Isolation | None | Containerized |

## License

This Docker configuration is provided as-is. The Google Photos Sync tool itself is licensed under the same terms as the main project.
