@echo off
REM Google Drive Client - Windows Batch Setup
REM This script sets up and runs the Google Drive Client container on Windows

setlocal enabledelayedexpansion

REM Set colors for output (works in modern Windows terminals)
set "RED="
set "GREEN="
set "YELLOW="
set "BLUE="
set "CYAN="
set "NC="

REM Check for ANSI color support
if defined ConEmuANSI set "COLOR_SUPPORT=1"
if defined TERM set "COLOR_SUPPORT=1"

if "%COLOR_SUPPORT%"=="1" (
    set "RED=^[[31m"
    set "GREEN=^[[32m"
    set "YELLOW=^[[33m"
    set "BLUE=^[[34m"
    set "CYAN=^[[36m"
    set "NC=^[[0m"
)

echo %CYAN%========================================%NC%
echo   Google Drive Client - Windows Setup
echo %CYAN%========================================%NC%
echo.

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\..\.."

cd /d "%PROJECT_DIR%"

REM Check if Docker is installed
if not exist "%SCRIPT_DIR%Dockerfile" (
    echo %RED%ERROR: Cannot find Docker files%NC%
    echo Expected: %SCRIPT_DIR%Dockerfile
    exit /b 1
)

echo %GREEN%[1/5] Checking Docker installation...%NC%

where docker >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%Docker Desktop is not installed%NC%
    echo.
    echo To install Docker Desktop for Windows:
    echo   1. Download from: https://www.docker.com/products/docker-desktop/
    echo   2. Install Docker Desktop
    echo   3. Ensure WSL 2 is enabled
    echo   4. Restart your computer
    echo   5. Start Docker Desktop
    echo   6. Run this script again
    echo.
    open "https://www.docker.com/products/docker-desktop/"
    pause
    exit /b 1
)

REM Check if Docker daemon is running
docker info >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%Docker is installed but daemon is not running%NC%
    echo.
    echo Please start Docker Desktop:
    echo   - Click the Docker whale icon in your system tray
    echo   - Wait for Docker Desktop to fully initialize
    echo   - Then run this script again
    echo.
    pause
    exit /b 1
)

echo %GREEN%Docker is installed and running%NC%

REM Create data directories if they don't exist
if not exist "credentials" (
    echo Creating directory structure...
    mkdir credentials
    mkdir config
    mkdir data
)

REM Check for existing container
echo %GREEN%[2/5] Checking for existing container...%NC%

for /f "tokens=1" %%i in ('docker ps -a --filter "name=google-drive-client" --format "{{.Names}}" 2^>nul') do (
    set "CONTAINER_EXISTS=%%i"
)

if defined CONTAINER_EXISTS (
    echo Container 'google-drive-client' already exists
) else
    echo No existing container found
    set CONTAINER_EXISTS=
)

REM Build the Docker image
echo %GREEN%[3/5] Building Docker image...%NC%

DOCKER_IMAGE=$(docker images -q google-drive-client 2>nul || true)

if "%DOCKER_IMAGE%"=="" (
    echo Building Docker image (this may take several minutes)...
    if docker build -t google-drive-client -f google_drive_client\docker\Dockerfile . (
        echo %GREEN%Docker image built successfully%NC%
    ) else (
        echo %RED%Failed to build Docker image%NC%
        echo Check Docker is running and your internet connection
        pause
        exit /b 1
    )
) else (
    echo Docker image already exists
)

REM Start the container
echo %GREEN%[4/5] Starting container...%NC%

if defined CONTAINER_EXISTS (
    echo Container exists. Starting it...
    if docker start google-drive-client (
        echo %GREEN%Container started%NC%
    ) else (
        echo %RED%Failed to start container%NC%
        pause
        exit /b 1
    )
) else (
    if docker-compose -f google_drive_client\docker\docker-compose.yml up -d (
        echo %GREEN%Container started with docker-compose%NC%
    ) else (
        echo %RED%Failed to start with docker-compose, trying docker run...%NC%
        if docker run -d --name google-drive-client -p 50200:50200 -v "%CD%/credentials:/app/credentials" -v "%CD%/config:/app/config" -v "%CD%/data:/app/data" google-drive-client (
            echo %GREEN%Container started with docker run%NC%
        ) else (
            echo %RED%Failed to start container%NC%
            pause
            exit /b 1
        )
    )
)

REM Give the container a moment to start
timeout /t 2 >nul 2>&1

REM Check if container is running
for /f "tokens=1,7" %%i in ('docker ps --filter "name=google-drive-client" --format "{{.Names}}|{{.Status}}" 2^>nul') do (
    if "%%j"=="Up" (
        echo %GREEN%Container is running!%NC%
        goto :CONTINUE
    )
)

echo %RED%Container failed to start%NC%
echo Check logs with: docker logs google-drive-client
pause
exit /b 1

:CONTINUE

echo.
echo %CYAN%========================================%NC%
echo   Setup Complete!
echo %CYAN%========================================%NC%
echo.

REM Check if credentials exist
if not exist "credentials\credentials.json" (
    if not exist "credentials\service-account.json" (
        echo %YELLOW%No credentials found%NC%
        echo.
        echo To use the Google Drive Client, you need to provide credentials:
        echo.
        echo Option 1: For Service Account
        echo   - Copy your service account JSON to: credentials\service-account.json
        echo   - Run: docker exec -it google-drive-client --help
        echo.
        echo Option 2: For OAuth (interactive)
        echo   - Run: docker exec -it -p 50200:50200 google-drive-client authorize <project-id> <client-id> <client-secret>
        echo   - This will open a browser for authentication
        echo   - Save the output to: credentials\credentials.json
        echo.
        echo Option 3: Mount existing credentials
        echo   - Copy your credentials.json to this directory
        echo.
        goto :USAGE
    )
)

:USAGE
echo.
echo %GREEN%How to use%NC%:
    echo.
    echo   Common commands:
    echo.
    echo   - Authorize OAuth:  docker exec -it google-drive-client authorize <project> <client-id> <secret>
    echo   - Create file:     docker exec -it google-drive-client create "My File" <folder-id>
    echo   - List files:      docker exec -it google-drive-client list-files <folder-id>
    echo   - Download file:    docker exec -it google-drive-client download <file-id> /app/data/output
    echo   - Share file:       docker exec -it google-drive-client share <file-id> reader --domain example.com
    echo.
    echo   Note: Downloaded files will be in the 'data' directory on your host
    echo.

echo %GREEN%Useful commands%NC%:
    echo   - View logs:     docker logs -f google-drive-client
    echo   - Stop:          docker stop google-drive-client
    echo   - Start:        docker start google-drive-client
    echo   - Restart:      docker restart google-drive-client
    echo   - Shell:        docker exec -it google-drive-client bash
    echo.

endlocal
pause
