@echo off
REM Google Photos Sync - Windows Batch Setup
REM This script checks Docker, builds the container, and starts the sync service

setlocal enabledelayedexpansion

REM Check if running as administrator (not strictly required for Docker on Windows)
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo WARNING: This script should be run as Administrator for best results.
    echo Some Docker operations may require admin privileges.
    echo.
    pause
)

REM Set colors for output
set "RED="
set "GREEN="
set "YELLOW="
set "BLUE="
set "NC="

if defined ConEmuANSI set "COLOR_SUPPORT=1"
if defined TERM set "COLOR_SUPPORT=1"

REM Define color codes for cmd.exe
if "%COLOR_SUPPORT%"=="1" (
    set "RED=^[[31m"
    set "GREEN=^[[32m"
    set "YELLOW=^[[33m"
    set "BLUE=^[[34m"
    set "NC=^[[0m"
)

echo %BLUE%========================================%NC%
echo   Google Photos Sync - Windows Setup
echo %BLUE%========================================%NC%
echo.

REM Check if we're in the correct directory
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\..\.."

if not exist "%PROJECT_DIR%\tools\google_photos_sync\docker\Dockerfile" (
    echo %RED%ERROR: This script must be run from the docker directory or project root%NC%
    echo Current directory: %CD%
    echo Expected location: %PROJECT_DIR%\tools\google_photos_sync\docker
    echo.
    echo Please navigate to: %~dp0
    pause
    exit /b 1
)

REM Navigate to project root
cd /d "%PROJECT_DIR%"

echo %GREEN%[1/4] Checking Docker installation...%NC%
echo.

REM Check if Docker is installed
where docker >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%Docker Desktop is not installed or not in PATH%NC%
    echo.
    echo To install Docker Desktop:
    echo   1. Download from: https://www.docker.com/products/docker-desktop/
    echo   2. Install Docker Desktop for Windows
    echo   3. Ensure WSL 2 is enabled (Docker will guide you)
    echo   4. Restart your computer
    echo   5. Run Docker Desktop (wait for it to fully start)
    echo   6. Then run this script again
    echo.
    echo Opening Docker Desktop download page in your browser...
    start "" "https://www.docker.com/products/docker-desktop/"
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
echo.

REM Check Docker Desktop version and WSL
for /f "tokens=2 delims=: " %%A in ('docker --version 2^>nul') do set "DOCKER_VERSION=%%A"
echo Using Docker: %DOCKER_VERSION%
echo.

REM Check WSL
wsl --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%WSL 2 is not installed%NC%
    echo.
    echo Docker Desktop on Windows requires WSL 2
    echo Installing WSL 2...
    echo.
    wsl --install --no-distribution
    if %errorLevel% neq 0 (
        echo %RED%Failed to install WSL 2 automatically%NC%
        echo Please install WSL 2 manually:
        echo   1. Open PowerShell as Administrator
        echo   2. Run: wsl --install
        echo   3. Restart your computer
        echo   4. Then run this script again
        echo.
        pause
        exit /b 1
    )
    echo.
    echo %GREEN%WSL 2 installed successfully%NC%
    echo Please restart your computer and run this script again.
    pause
    exit /b 0
)

REM Ensure file sharing is set up for the current drive
set "CURRENT_DRIVE=%CD:~0,2%"

echo %GREEN%[2/4] Checking Docker file sharing for drive %CURRENT_DRIVE%...%NC%

REM We can't programmatically check file sharing, but we can warn the user
REM Docker Desktop file sharing is typically set up during installation
echo %YELLOW%Note: Ensure Docker Desktop has file sharing enabled for drive %CURRENT_DRIVE%%NC%
if not exist "%PROJECT_DIR%\Photos_Sync" (
    echo Creating Photos_Sync directory...
    mkdir "%PROJECT_DIR%\Photos_Sync"
    mkdir "%PROJECT_DIR%\Photos_Sync\Watch"
    mkdir "%PROJECT_DIR%\Photos_Sync\Uploaded"
    mkdir "%PROJECT_DIR%\Photos_Sync\Logs"
    mkdir "%PROJECT_DIR%\Photos_Sync\config"
)
echo.

echo %GREEN%[3/4] Building Docker image...%NC%
echo This may take several minutes the first time
echo.

REM Build the Docker image
docker build -t google-photos-sync -f tools\google_photos_sync\docker\Dockerfile .
if %errorLevel% neq 0 (
    echo %RED%Failed to build Docker image%NC%
    echo Check the error messages above
    echo.
    pause
    exit /b 1
)

echo %GREEN%Docker image built successfully%NC%
echo.

echo %GREEN%[4/4] Starting container...%NC%

REM Start the container using docker-compose
docker-compose -f tools\google_photos_sync\docker-compose.yml up -d
if %errorLevel% neq 0 (
    echo %RED%Failed to start container%NC%
    echo Trying alternative method...
    echo.
    docker run -d --name google-photos-sync -v "%CD%/Photos_Sync:/app/data" google-photos-sync start
    if %errorLevel% neq 0 (
        echo %RED%Failed to start container with both methods%NC%
        echo Check Docker is running and try again
        echo.
        pause
        exit /b 1
    )
)

echo %GREEN%Container started successfully!%NC%
echo.
echo %BLUE%========================================%NC%
echo   Setup Complete
%BLUE%========================================%NC%
echo.
echo Next steps:
echo.
echo %GREEN%1. Configure rclone for Google Photos%NC%:
    echo   Run: docker exec -it google-photos-sync rclone config --config=/app/data/config/rclone.conf
    echo   Follow the prompts to authenticate with Google
echo.
echo %GREEN%2. Edit your configuration%NC%:
    echo   Open: %CD%\Photos_Sync\config\config.env
    echo   Set: RCLONE_REMOTE=google_photos (or your remote name)
    echo   Set: RCLONE_ALBUM=YourAlbumName
echo.
echo %GREEN%3. Add photos to sync%NC%:
    echo   Copy photos to: %CD%\Photos_Sync\Watch\\
echo   They will automatically upload to Google Photos
echo.
echo %GREEN%4. View logs%NC%:
    echo   Command: docker logs -f google-photos-sync
echo.
echo %GREEN%5. Check status%NC%:
    echo   Command: docker exec google-photos-sync google-photos-sync status
echo.
echo %BLUE%========================================%NC%
echo.

REM Open the config file for editing
if exist "%CD%\Photos_Sync\config\config.env" (
    echo Opening configuration file...
    start notepad "%CD%\Photos_Sync\config\config.env"
) else (
    echo Creating default configuration file...
    docker exec google-photos-sync bash -c "if [ ! -f /app/data/config/config.env ]; then /app/google_photos_sync/setup_container.sh; fi"
    start notepad "%CD%\Photos_Sync\config\config.env"
)

echo.
echo %GREEN%All done!%NC%
echo Your Google Photos Sync is now running in Docker.
echo Drop photos into Photos_Sync\Watch\ to start syncing.
echo.

endlocal
pause
