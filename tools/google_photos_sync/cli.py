"""
Google Photos Sync - Command Line Interface

This module provides a CLI for managing the Google Photos Sync tool.
"""

import sys
import typer
from pathlib import Path
from typing import Optional

from . import GooglePhotosSync

app = typer.Typer(
    name="google-photos-sync",
    help="Manage Google Photos Sync - automated photo upload to Google Photos",
    add_completion=False,
)

# Global sync instance
sync: Optional[GooglePhotosSync] = None


def get_sync() -> GooglePhotosSync:
    """Get or create the GooglePhotosSync instance."""
    global sync
    if sync is None:
        sync = GooglePhotosSync()
    return sync


@app.command(name="setup", help="Install dependencies and set up the sync environment")
def setup_command(
    debug: bool = typer.Option(False, "-d", "--debug", help="Enable debug output"),
):
    """Run the setup script to install rclone, fswatch, and create directories."""
    sync = get_sync()
    typer.echo("Running setup...\n")
    
    if sync.run_setup(debug=debug):
        typer.echo("\n✓ Setup completed successfully!")
        typer.echo("\nNext steps:")
        typer.echo("  1. Configure rclone: rclone config")
        typer.echo("  2. Edit ~/Photos_Sync/config.env to set your remote and album")
        typer.echo("  3. Start the monitor: google-photos-sync start")
    else:
        typer.echo("\n✗ Setup failed. Check error messages above.", err=True)
        raise typer.Exit(code=1)


@app.command(name="start", help="Start the file monitor")
def start_command(
    debug: bool = typer.Option(False, "-d", "--debug", help="Enable debug output"),
    foreground: bool = typer.Option(False, "-f", "--foreground", help="Run in foreground (blocking)"),
):
    """Start the fswatch monitor to watch for new files."""
    sync = get_sync()
    typer.echo("Starting Google Photos Sync monitor...")
    typer.echo(f"  Watch directory: {sync.watch_dir}")
    typer.echo(f"  Upload directory: {sync.uploaded_dir}")
    typer.echo(f"  Log directory: {sync.log_dir}\n")
    
    process = sync.start_monitor(debug=debug)
    
    if foreground:
        typer.echo("Running in foreground. Press Ctrl+C to stop.\n")
        try:
            # Print output in real-time
            while True:
                line = process.stdout.readline()
                if not line:
                    break
                typer.echo(line.strip())
        except KeyboardInterrupt:
            typer.echo("\n\nStopping monitor...")
            sync.stop_monitor(process)
    else:
        typer.echo(f"Monitor started in background (PID: {process.pid})")
        typer.echo("Use 'google-photos-sync stop' to stop the monitor.")


@app.command(name="stop", help="Stop a running monitor process")
def stop_command(
    pid: Optional[int] = typer.Argument(None, help="PID of the monitor process to stop"),
):
    """Stop the running fswatch monitor."""
    sync = get_sync()
    
    if pid is None:
        typer.echo("No PID specified. This command currently requires a PID.")
        typer.echo("In a future version, this will detect running processes automatically.")
        typer.echo("\nTo stop manually:")
        typer.echo("  1. Find the PID: ps aux | grep start_watch.sh")
        typer.echo("  2. Kill the process: kill <PID>")
        raise typer.Exit(code=0)
    
    # Create a mock process object
    import subprocess
    mock_process = subprocess.Popen([f"dummy_{pid}"])
    mock_process.pid = pid
    
    if sync.stop_monitor(mock_process):
        typer.echo(f"✓ Monitor process {pid} stopped successfully")
    else:
        typer.echo(f"✗ Failed to stop monitor process {pid}", err=True)
        raise typer.Exit(code=1)


@app.command(name="upload", help="Upload a single file to Google Photos")
def upload_command(
    file_path: Path = typer.Argument(..., help="Path to the file to upload"),
    debug: bool = typer.Option(False, "-d", "--debug", help="Enable debug output"),
):
    """Upload a single file to Google Photos."""
    sync = get_sync()
    
    if not file_path.exists():
        typer.echo(f"✗ File not found: {file_path}", err=True)
        raise typer.Exit(code=1)
    
    if not file_path.is_file():
        typer.echo(f"✗ Not a regular file: {file_path}", err=True)
        raise typer.Exit(code=1)
    
    typer.echo(f"Uploading {file_path} to Google Photos...")
    
    if sync.upload_file(file_path, debug=debug):
        typer.echo(f"✓ Upload completed successfully")
    else:
        typer.echo(f"✗ Upload failed. Check logs for details.", err=True)
        raise typer.Exit(code=1)


@app.command(name="status", help="Check the status of the sync system")
def status_command(
    json_output: bool = typer.Option(False, "-j", "--json", help="Output in JSON format"),
):
    """Display the current status of the sync system."""
    import json
    sync = get_sync()
    status = sync.get_status()
    
    if json_output:
        typer.echo(json.dumps(status, indent=2))
    else:
        typer.echo("Google Photos Sync Status")
        typer.echo("=" * 40)
        typer.echo(f"\nWatch directory:    {status['watch_dir']}")
        typer.echo(f"Upload directory:   {status['uploaded_dir']}")
        typer.echo(f"Log directory:      {status['log_dir']}\n")
        
        typer.echo("Dependencies:")
        typer.echo(f"  rclone:   {'✓ installed' if status.get('rclone_installed') else '✗ not installed'}")
        typer.echo(f"  fswatch:  {'✓ installed' if status.get('fswatch_installed') else '✗ not installed'}\n")
        
        typer.echo("Scripts:")
        typer.echo(f"  setup.sh:      {'✓' if status['scripts'].get('setup') else '✗'}")
        typer.echo(f"  start_watch.sh: {'✓' if status['scripts'].get('start') else '✗'}")
        typer.echo(f"  upload_worker.sh: {'✓' if status['scripts'].get('worker') else '✗'}")
        typer.echo(f"  plist:         {'✓' if status['scripts'].get('plist') else '✗'}\n")
        
        typer.echo("Directories:")
        typer.echo(f"  Watch:    {'✓ exists' if status['directories'].get('watch') else '✗ missing'}")
        typer.echo(f"  Uploaded: {'✓ exists' if status['directories'].get('uploaded') else '✗ missing'}")
        typer.echo(f"  Log:      {'✓ exists' if status['directories'].get('log') else '✗ missing'}")


@app.command(name="logs", help="View or download log files")
def logs_command(
    log_type: str = typer.Argument("all", help="Type of log to view (worker, monitor, fswatch, stdout, stderr, all)"),
    lines: Optional[int] = typer.Option(None, "-n", "--lines", help="Number of lines to show from the end"),
):
    """Display log file contents."""
    sync = get_sync()
    logs = sync.get_logs(log_type)
    
    if not logs:
        typer.echo("No logs found.")
        raise typer.Exit(code=0)
    
    for name, content in logs.items():
        if content and "not found" not in content:
            typer.echo(f"\n{'='*60}")
            typer.echo(f"Log: {name}")
            typer.echo('='*60)
            
            if lines:
                # Show last N lines
                log_lines = content.split('\n')
                content = '\n'.join(log_lines[-lines:])
            
            typer.echo(content)


@app.command(name="install-service", help="Install as a launchd service (auto-start on login)")
def install_service_command():
    """Install the Google Photos Sync as a launchd service."""
    sync = get_sync()
    
    typer.echo("Installing launchd service...")
    
    if sync.install_launchd_service():
        typer.echo("✓ launchd service installed successfully")
        typer.echo("\nThe monitor will start automatically when you log in.")
        typer.echo("\nTo start immediately:")
        typer.echo("  launchctl start com.local.google-photos-sync")
        typer.echo("\nTo stop:")
        typer.echo("  launchctl stop com.local.google-photos-sync")
        typer.echo("\nTo uninstall:")
        typer.echo("  google-photos-sync uninstall-service")
    else:
        typer.echo("✗ Failed to install launchd service", err=True)
        raise typer.Exit(code=1)


@app.command(name="uninstall-service", help="Uninstall the launchd service")
def uninstall_service_command():
    """Uninstall the Google Photos Sync launchd service."""
    sync = get_sync()
    
    typer.echo("Uninstalling launchd service...")
    
    if sync.uninstall_launchd_service():
        typer.echo("✓ launchd service uninstalled successfully")
    else:
        typer.echo("✗ Failed to uninstall launchd service", err=True)
        raise typer.Exit(code=1)


# Main entry point
def main():
    app()


if __name__ == "__main__":
    main()
