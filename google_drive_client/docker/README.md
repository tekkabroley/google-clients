# Google Drive Client - Docker Container

Run the Google Drive Client CLI on **Windows, macOS, or Linux** using Docker containers. This eliminates the need for platform-specific Python installations and dependency management.

## Quick Start

### Windows Users

**Easiest method:** Double-click:
```
google_drive_client\docker\start_windows.bat
```

Or from Command Prompt:
```cmd
cd C:\path\to\google-clients\google_drive_client\docker
start_windows.bat
```

### macOS/Linux Users

**Easiest method:** Run the shell script:
```bash
cd /path/to/google-clients/google_drive_client/docker
./start_macos.sh
```

Or manually:
```bash
# Build and start with docker-compose
docker-compose -f docker-compose.yml up -d

# View logs
docker-compose logs -f
```

---

## Detailed Instructions

### 1. Prerequisites

#### Docker Installation

- **Windows:** [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
- **macOS:** [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
- **Linux:** Install Docker Engine for your distribution

#### Google API Credentials

You need Google API credentials to use this tool. You have two options:

**Option A: Service Account (Recommended for automation)**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to "IAM & Admin" > "Service Accounts"
4. Create a new service account
5. Generate a JSON key file and save it as `credentials/service-account.json`
6. Enable the Google Drive API for your project

**Option B: OAuth 2.0 (For user authentication)**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to "APIs & Services" > "Credentials"
4. Create OAuth 2.0 credentials (Desktop app type)
5. Note your Client ID and Client Secret
6. You'll need to run the `authorize` command (see below)

---

### 2. Directory Structure

After running the setup, you'll have:
```
google_drive_client/
├── docker/              # Docker files
│   ├── Dockerfile      # Container definition
│   ├── docker-compose.yml # Docker Compose config
│   └── README.md       # This file
├── docker-compose.yml  # Root-level Docker Compose (convenience)
├── credentials/        # Google API credentials (create this)
│   ├── credentials.json # OAuth user credentials
│   └── service-account.json # Service account credentials
├── config/             # Configuration files
│   └── .env            # Environment variables
└── data/               # Downloads and temporary files
```

---

### 3. Setup and Configuration

#### Using the Setup Scripts

**Windows:**
```cmd
cd google_drive_client\docker
start_windows.bat
```

**macOS/Linux:**
```bash
cd google_drive_client/docker
./start_macos.sh
```

These scripts will:
- Check Docker is installed and running
- Create necessary directories
- Build the Docker image
- Start the container
- Guide you through credential setup

#### Manual Setup

```bash
# Navigate to project root
cd /path/to/google-clients

# Build the Docker image
docker build -t google-drive-client -f google_drive_client/docker/Dockerfile .

# Create directories
mkdir -p google_drive_client/credentials
mkdir -p google_drive_client/config
mkdir -p google_drive_client/data

# Start the container
docker-compose -f google_drive_client/docker-compose.yml up -d
```

---

### 4. Authentication

#### For Service Account

1. Copy your service account JSON file to `google_drive_client/credentials/service-account.json`
2. The container will automatically use it

#### For OAuth 2.0

Run the authorize command:
```bash
# Run this command and follow the prompts
docker exec -it google-drive-client authorize <project-id> <client-id> <client-secret>
```

This will:
1. Start a local server on port 50200
2. Open a browser window for you to authenticate
3. Print the OAuth credentials to the console
4. Copy the JSON output and save it to `google_drive_client/credentials/credentials.json`

---

### 5. Using the CLI

#### Common Commands

All commands are run through `docker exec`:

```bash
# Create a new file (sheet, doc, etc.)
docker exec -it google-drive-client create "My Spreadsheet" <folder-id> --mime-type application/vnd.google-apps.spreadsheet

# List files in a folder
docker exec -it google-drive-client list-files <folder-id>

# Download a file
docker exec -it google-drive-client download <file-id> /app/data/myfile.pdf

# Share a file
docker exec -it google-drive-client share <file-id> reader --domain example.com

# Share with specific user
docker exec -it google-drive-client share <file-id> writer --user user@example.com
```

#### Finding Folder IDs and File IDs

1. Go to [Google Drive](https://drive.google.com/)
2. Navigate to the folder or file
3. The ID is in the URL: `https://drive.google.com/drive/folders/<FOLDER-ID>`

#### CLI Commands Reference

| Command | Description |
|---------|-------------|
| `authorize <project> <client-id> <secret>` | OAuth authentication |
| `create <title> <folder-id>` | Create a new file |
| `list-files <folder-id>` | List files in a folder |
| `download <file-id> <path>` | Download a file |
| `share <file-id> <role> [--domain|--user]` | Share a file |

**Role options:** `reader`, `writer`, `commenter`, `organizer`, `owner`

---

### 6. Platform-Specific Notes

#### Windows

On Windows, use PowerShell or CMD:

```powershell
# Build and run
docker build -t google-drive-client -f google_drive_client\docker\Dockerfile .

# Start with volume mounts
docker run -d --name google-drive-client ^
  -v ${PWD}\credentials:/app/credentials ^
  -v ${PWD}\config:/app/config ^
  -v ${PWD}\data:/app/data ^
  -p 50200:50200 ^
  google-drive-client
```

**Note:** Ensure Docker Desktop has file sharing enabled for your drive.

#### macOS

On macOS:

```bash
# Build and run
docker build -t google-drive-client -f google_drive_client/docker/Dockerfile .

# Start with volume mounts
docker run -d --name google-drive-client \
  -v $(pwd)/credentials:/app/credentials \
  -v $(pwd)/config:/app/config \
  -v $(pwd)/data:/app/data \
  -p 50200:50200 \
  google-drive-client
```

#### Linux

Same as macOS. Ensure Docker is installed and running.

---

### 7. Environment Variables

You can set environment variables in the container:

```bash
# Using docker run
docker run -d \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/credentials/service-account.json \
  --name google-drive-client \
  google-drive-client

# Using docker-compose
services:
  google-drive-client:
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/app/credentials/service-account.json
```

**Available environment variables:**
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to service account JSON file
- `GOOGLE_CLIENT_CREDENTIALS`: Path to OAuth client credentials (use `file://` prefix)
- `DEBUG`: Set to `true` for verbose output

---

### 8. Troubleshooting

#### Common Issues

**"No credentials found" error**
- Ensure your credentials file is in the correct location
- For service account: `credentials/service-account.json`
- For OAuth: `credentials/credentials.json`
- Check file permissions: `chmod 600 credentials/*.json`

**"Permission denied" when accessing files**
- Check volume mount permissions
- On macOS/Windows: Docker file sharing may need configuration
- Try: `chmod -R 777 google_drive_client/`

**OAuth authentication not working**
- Ensure port 50200 is not blocked
- Check firewall settings
- Try running with `-p 50200:50200` explicitly

**"Module not found" errors**
- Ensure the Docker image was built correctly
- Check Python dependencies are installed: `docker exec google-drive-client pip list`

#### Debug Mode

Enable debug output:
```bash
docker exec -it google-drive-client bash
export DEBUG=true
python -m google_drive_client.cli --help
```

Or set in docker-compose:
```yaml
environment:
  - DEBUG=true
```

---

### 9. Useful Docker Commands

| Action | Command |
|--------|---------|
| Start container | `docker start google-drive-client` |
| Stop container | `docker stop google-drive-client` |
| Restart container | `docker restart google-drive-client` |
| View logs | `docker logs -f google-drive-client` |
| Open shell | `docker exec -it google-drive-client bash` |
| Remove container | `docker rm google-drive-client` |
| Remove image | `docker rmi google-drive-client` |
| View running containers | `docker ps` |
| View all containers | `docker ps -a` |

---

### 10. Examples

#### Example 1: Create a new spreadsheet
```bash
# Create a spreadsheet in the root folder (use 'root' for root)
docker exec -it google-drive-client create "My Spreadsheet" root
```

#### Example 2: List all files in a folder
```bash
# List files in a specific folder
docker exec -it google-drive-client list-files FOLDER_ID_HERE
```

#### Example 3: Download a spreadsheet as PDF
```bash
# Download and convert to PDF
docker exec -it google-drive-client download FILE_ID_HERE /app/data/output.pdf
```

#### Example 4: Share a file with a domain
```bash
# Share with all users in a domain
docker exec -it google-drive-client share FILE_ID_HERE commenter --domain example.com
```

#### Example 5: Full OAuth setup
```bash
# First, authorize (opens browser)
docker exec -it -p 50200:50200 google-drive-client authorize my-project my-client-id my-client-secret

# Copy the output JSON to credentials/credentials.json
# Then use the CLI
docker exec -it google-drive-client list-files root
```

---

### 11. Uninstalling

```bash
# Stop and remove container
docker stop google-drive-client
docker rm google-drive-client

# Remove Docker image
docker rmi google-drive-client

# Remove data directories (optional)
rm -rf google_drive_client/
```

---

## Architecture

The Docker container includes:

- **Base**: Python 3.11 slim
- **Dependencies**: All Python packages from pyproject.toml
  - google-api-python-client
  - google-auth-httplib2
  - google-auth-oauthlib
  - pydantic-settings
  - typer
- **Port**: 50200 (for OAuth callback)
- **Volumes**: credentials, config, data

## License

This Docker configuration is provided as-is. The Google Drive Client itself is licensed under the same terms as the main project.
