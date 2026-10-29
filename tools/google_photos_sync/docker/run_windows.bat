@echo off
REM Google Photos Sync - Windows Run Script
REM Quick script to start the container (after initial setup)

setlocal

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\..\.."

cd /d "%PROJECT_DIR%"

echo Starting Google Photos Sync container...
echo.

REM Check if container exists
for /f "tokens=1" %%i in ('docker ps -a --filter "name=google-photos-sync" --format "{{.Names}}" 2^>nul') do (
    set "CONTAINER_EXISTS=%%i"
)

if defined CONTAINER_EXISTS (
    echo Container already exists. Starting it...
    docker start google-photos-sync
) else (
    echo Container not found. Building and starting...
    docker build -t google-photos-sync -f tools\google_photos_sync\docker\Dockerfile . >nul 2>&1
    docker-compose -f tools\google_photos_sync\docker-compose.yml up -d
)

REM Check if it started successfully
timeout /t 2 >nul 2>&1
for /f "tokens=1,7" %%i in ('docker ps --filter "name=google-photos-sync" --format "{{.Names}}|{{.Status}}" 2^>nul') do (
    if "%%j"=="Up" (
        echo Success! Container is running.
        goto :DONE
    )
)

echo Error: Container failed to start. Check Docker Desktop and run start_windows.bat
pause
goto :EOF

:DONE
echo.
echo Google Photos Sync is now running.
echo Drop photos into Photos_Sync\Watch\ to start syncing.
echo To stop: docker stop google-photos-sync

endlocal
