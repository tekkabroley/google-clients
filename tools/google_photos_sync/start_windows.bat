@echo off
REM Google Photos Sync - Windows Quick Start
REM This script sets up and runs the Google Photos Sync container on Windows

setlocal enabledelayedexpansion

REM Set colors for output (works in modern Windows terminals)
set "RED="
set "GREEN="
set "YELLOW="
set "BLUE="
set "NC="

REM Check for ANSI color support
if defined ConEmuANSI set "COLOR_SUPPORT=1"
if defined TERM set "COLOR_SUPPORT=1"

if "%COLOR_SUPPORT%"=="1" (
    set "RED=^[[31m"
    set "GREEN=^[[32m"
    set "YELLOW=^[[33m"
    set "BLUE=^[[34m"
    set "NC=^[[0m"
)

echo %BLUE%========================================%NC%
echo   Google Photos Sync - Windows Quick Start
echo %BLUE%========================================%NC%
echo.

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "DOCKER_DIR=%SCRIPT_DIR%docker"

if not exist "%DOCKER_DIR%\Dockerfile" (
    echo %RED%ERROR: Cannot find Docker files%NC%
    echo Expected location: %DOCKER_DIR%\Dockerfile
    echo Current location: %SCRIPT_DIR%
    echo.
    pause
    exit /b 1
)

REM Navigate to the google_photos_sync directory
cd /d "%SCRIPT_DIR%"

echo %GREEN%[1/5] Checking Docker installation...%NC%

REM Check if Docker is installed
where docker >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%Docker Desktop is not installed%NC%
    echo.
    echo To use this tool, you need Docker Desktop for Windows:
    echo   1. Download from: https://www.docker.com/products/docker-desktop/
    echo   2. Install Docker Desktop
    echo   3. Ensure WSL 2 is enabled (Docker will guide you)
    echo   4. Restart your computer
    echo   5. Start Docker Desktop and wait for it to initialize
    echo   6. Run this script again
    echo.
    echo Opening Docker Desktop download page...
    start "" "https://www.docker.com/products/docker-desktop/"
    pause
    exit /b 1
)

REM Check if Docker daemon is running
docker info >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%Docker is installed but not running%NC%
    echo.
    echo Please start Docker Desktop:
    echo   - Click the Docker whale icon in your system tray
    echo   - Wait for Docker Desktop to fully initialize (this can take a minute)
    echo   - Then run this script again
    echo.
    pause
    exit /b 1
)

echo %GREEN%Docker is installed and running%NC%
echo.

REM Create data directories if they don't exist
if not exist "Photos_Sync" (
    echo Creating Photos_Sync directory structure...
    mkdir Photos_Sync
    mkdir Photos_Sync\Watch
    mkdir Photos_Sync\Uploaded
    mkdir Photos_Sync\Logs
    mkdir Photos_Sync\config
)
echo.

echo %GREEN%[2/5] Building Docker image...%NC%
echo This may take 5-10 minutes the first time
echo.

REM Build the Docker image
docker build -t google-photos-sync -f docker\Dockerfile ..
if %errorLevel% neq 0 (
    echo %RED%Failed to build Docker image%NC%
    echo Check the error messages above
    echo.
    echo Common fixes:
    echo   - Ensure Docker Desktop is running
    echo   - Ensure you have internet connectivity
    echo   - Ensure WSL 2 is installed and working
    echo.
    pause
    exit /b 1
)

echo %GREEN%Docker image built successfully%NC%
echo.

echo %GREEN%[3/5] Starting container...%NC%

REM Start the container using docker-compose
docker-compose -f docker-compose.yml up -d
if %errorLevel% neq 0 (
    echo %RED%Failed to start with docker-compose%NC%
    echo Trying with docker run...
    docker run -d --name google-photos-sync -v "%CD%/Photos_Sync:/app/data" google-photos-sync start
    if %errorLevel% neq 0 (
        echo %RED%Failed to start container%NC%
        echo Check Docker is running and try again
        echo.
        pause
        exit /b 1
    )
)

echo %GREEN%Container started successfully!%NC%
echo.

REM Give the container a moment to start
ping -n 3 127.0.0.1 >nul 2>&1

echo %GREEN%[4/5] Configuring rclone...%NC%
echo.
echo Please follow the prompts to authenticate with Google Photos
echo This will open a browser window for OAuth authentication
echo.

REM Configure rclone interactively
docker exec -it google-photos-sync rclone config --config=/app/data/config/rclone.conf
if %errorLevel% neq 0 (
    echo %YELLOW%Failed to configure rclone automatically%NC%
    echo You can configure it manually:
    echo   docker exec -it google-photos-sync bash
    echo   rclone config --config=/app/data/config/rclone.conf
)

echo.
echo %GREEN%[5/5] Setting up configuration...%NC%

REM Create default config if it doesn't exist
if not exist "Photos_Sync\config\config.env" (
    echo Creating default configuration file...
    docker exec google-photos-sync bash -c "if [ ! -f /app/data/config/config.env ]; then /app/google_photos_sync/setup_container.sh; fi"
)

echo.
echo %BLUE%========================================%NC%
echo   SETUP COMPLETE!
%BLUE%========================================%NC%
echo.
echo Your Google Photos Sync is now running in Docker.
echo.
echo %GREEN%How to use%NC%:
    echo   1. Drop photos into: %CD%\Photos_Sync\Watch\\
    echo   2. They will automatically upload to Google Photos
    echo   3. Uploaded files move to: %CD%\Photos_Sync\Uploaded\\
echo.
echo %GREEN%Useful commands%NC%:
    echo   - View logs:         docker logs -f google-photos-sync
    echo   - Stop container:    docker stop google-photos-sync
    echo   - Start container:   docker start google-photos-sync
    echo   - Restart:           docker restart google-photos-sync
    echo   - Status:            docker exec google-photos-sync google-photos-sync status
    echo   - Open shell:        docker exec -it google-photos-sync bash
    echo.
echo %GREEN%Edit your configuration%NC%:
    echo   File: %CD%\Photos_Sync\config\config.env
    echo   Open this file in Notepad to customize your settings
echo.

REM Open the config file for editing
if exist "Photos_Sync\config\config.env" (
    echo Opening configuration file in Notepad...
    start notepad "Photos_Sync\config\config.env"
)

echo.
echo %GREEN%Tip: Test by copying a photo to Photos_Sync\Watch\\%NC%
echo.

endlocal
pause
