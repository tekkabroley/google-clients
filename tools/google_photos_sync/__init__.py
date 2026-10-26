"""
Google Photos Sync Tool

A lightweight, background-capable automation system that watches a local directory
on macOS, waits for incoming image files to completely finish writing, and uploads
them to Google Photos using rclone.

This package provides a Python interface to the bash-based sync system.
"""

import subprocess
import sys
from pathlib import Path
from typing import Optional, List

# Package metadata
__version__ = "1.0.0"
__author__ = "Alex Broley"
__description__ = "Google Photos Sync Tool with rclone and fswatch"

# Default paths
DEFAULT_TOOL_DIR = Path(__file__).parent
DEFAULT_WATCH_DIR = Path.home() / "Photos_Sync" / "Watch"
DEFAULT_UPLOADED_DIR = Path.home() / "Photos_Sync" / "Uploaded"
DEFAULT_LOG_DIR = Path.home() / "Photos_Sync" / "Logs"


class GooglePhotosSync:
    """
    Python interface for the Google Photos Sync tool.
    
    This class provides methods to control the bash-based sync system
    and check its status.
    """
    
    def __init__(
        self,
        tool_dir: Optional[Path] = None,
        watch_dir: Optional[Path] = None,
        uploaded_dir: Optional[Path] = None,
        log_dir: Optional[Path] = None,
    ):
        """
        Initialize the Google Photos Sync interface.
        
        Args:
            tool_dir: Directory containing the sync scripts (default: package directory)
            watch_dir: Directory to watch for new files (default: ~/Photos_Sync/Watch)
            uploaded_dir: Directory for archived files (default: ~/Photos_Sync/Uploaded)
            log_dir: Directory for log files (default: ~/Photos_Sync/Logs)
        """
        self.tool_dir = tool_dir or DEFAULT_TOOL_DIR
        self.watch_dir = watch_dir or DEFAULT_WATCH_DIR
        self.uploaded_dir = uploaded_dir or DEFAULT_UPLOADED_DIR
        self.log_dir = log_dir or DEFAULT_LOG_DIR
        
        # Paths to scripts
        self.setup_script = self.tool_dir / "setup.sh"
        self.start_script = self.tool_dir / "start_watch.sh"
        self.worker_script = self.tool_dir / "upload_worker.sh"
        self.plist_file = self.tool_dir / "com.local.google-photos-sync.plist"
        
        # Environment variables
        self.env = {
            "WATCH_DIR": str(self.watch_dir),
            "UPLOADED_DIR": str(self.uploaded_dir),
            "LOG_DIR": str(self.log_dir),
            "PATH": f"{self.tool_dir}:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin",
        }
    
    def run_setup(self, debug: bool = False) -> bool:
        """
        Run the setup script to install dependencies and create directories.
        
        Args:
            debug: Enable debug output
            
        Returns:
            True if setup succeeded, False otherwise
        """
        cmd = [str(self.setup_script)]
        if debug:
            self.env["DEBUG"] = "true"
        
        try:
            result = subprocess.run(
                cmd,
                check=True,
                env=self.env,
                capture_output=True,
                text=True,
            )
            print(result.stdout)
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Setup failed: {e}", file=sys.stderr)
            print(e.stdout, file=sys.stderr)
            print(e.stderr, file=sys.stderr)
            return False
    
    def start_monitor(self, debug: bool = False) -> subprocess.Popen:
        """
        Start the file monitor (fswatch) in the background.
        
        Args:
            debug: Enable debug output
            
        Returns:
            subprocess.Popen object for the running process
        """
        cmd = [str(self.start_script)]
        env = self.env.copy()
        if debug:
            env["DEBUG"] = "true"
        
        process = subprocess.Popen(
            cmd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return process
    
    def stop_monitor(self, process: subprocess.Popen) -> bool:
        """
        Stop a running monitor process.
        
        Args:
            process: The subprocess.Popen object from start_monitor()
            
        Returns:
            True if stopped successfully, False otherwise
        """
        try:
            process.terminate()
            process.wait(timeout=5)
            return True
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            return True
        except Exception as e:
            print(f"Error stopping monitor: {e}", file=sys.stderr)
            return False
    
    def upload_file(self, file_path: Path, debug: bool = False) -> bool:
        """
        Upload a single file to Google Photos.
        
        Args:
            file_path: Path to the file to upload
            debug: Enable debug output
            
        Returns:
            True if upload succeeded, False otherwise
        """
        # Check if file exists
        if not file_path.exists() or not file_path.is_file():
            print(f"File does not exist or is not a regular file: {file_path}", file=sys.stderr)
            return False
        
        cmd = [str(self.worker_script), str(file_path)]
        env = self.env.copy()
        if debug:
            env["DEBUG"] = "true"
        
        try:
            result = subprocess.run(
                cmd,
                check=True,
                env=env,
                capture_output=True,
                text=True,
            )
            print(result.stdout)
            if result.stderr:
                print(result.stderr, file=sys.stderr)
            return True
        except subprocess.CalledProcessError as e:
            print(f"Upload failed: {e}", file=sys.stderr)
            print(e.stdout, file=sys.stderr)
            print(e.stderr, file=sys.stderr)
            return False
    
    def install_launchd_service(self) -> bool:
        """
        Install the launchd service for auto-start on login.
        
        Returns:
            True if installed successfully, False otherwise
        """
        launch_agents_dir = Path.home() / "Library" / "LaunchAgents"
        plist_dest = launch_agents_dir / "com.local.google-photos-sync.plist"
        
        try:
            # Create LaunchAgents directory if it doesn't exist
            launch_agents_dir.mkdir(parents=True, exist_ok=True)
            
            # Copy plist file
            import shutil
            shutil.copy(str(self.plist_file), str(plist_dest))
            
            # Load the service
            subprocess.run(
                ["launchctl", "load", str(plist_dest)],
                check=True,
                capture_output=True,
            )
            
            # Start the service
            subprocess.run(
                ["launchctl", "start", "com.local.google-photos-sync"],
                check=True,
                capture_output=True,
            )
            
            print(f"launchd service installed and started: {plist_dest}")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"Failed to install launchd service: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error installing launchd service: {e}", file=sys.stderr)
            return False
    
    def uninstall_launchd_service(self) -> bool:
        """
        Uninstall the launchd service.
        
        Returns:
            True if uninstalled successfully, False otherwise
        """
        try:
            # Stop the service
            subprocess.run(
                ["launchctl", "stop", "com.local.google-photos-sync"],
                check=False,
                capture_output=True,
            )
            
            # Unload the service
            subprocess.run(
                ["launchctl", "unload", 
                 str(Path.home() / "Library" / "LaunchAgents" / "com.local.google-photos-sync.plist")],
                check=True,
                capture_output=True,
            )
            
            print("launchd service stopped and unloaded")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"Failed to uninstall launchd service: {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"Error uninstalling launchd service: {e}", file=sys.stderr)
            return False
    
    def get_status(self) -> dict:
        """
        Get the current status of the sync system.
        
        Returns:
            Dictionary with status information
        """
        status = {
            "watch_dir": str(self.watch_dir),
            "uploaded_dir": str(self.uploaded_dir),
            "log_dir": str(self.log_dir),
            "scripts": {
                "setup": self.setup_script.exists(),
                "start": self.start_script.exists(),
                "worker": self.worker_script.exists(),
                "plist": self.plist_file.exists(),
            },
        }
        
        # Check if rclone and fswatch are installed
        try:
            status["rclone_installed"] = subprocess.run(
                ["which", "rclone"],
                capture_output=True,
                check=True,
            ).returncode == 0
        except Exception:
            status["rclone_installed"] = False
        
        try:
            status["fswatch_installed"] = subprocess.run(
                ["which", "fswatch"],
                capture_output=True,
                check=True,
            ).returncode == 0
        except Exception:
            status["fswatch_installed"] = False
        
        # Check if directories exist
        status["directories"] = {
            "watch": self.watch_dir.exists(),
            "uploaded": self.uploaded_dir.exists(),
            "log": self.log_dir.exists(),
        }
        
        return status
    
    def get_logs(self, log_type: str = "all") -> dict:
        """
        Get log file contents.
        
        Args:
            log_type: Type of log to retrieve ("worker", "monitor", "fswatch", "all")
            
        Returns:
            Dictionary with log file paths and contents
        """
        logs = {}
        log_files = [
            ("worker", self.log_dir / "upload_worker.log"),
            ("monitor", self.log_dir / "monitor.log"),
            ("fswatch", self.log_dir / "fswatch.log"),
            ("stdout", self.log_dir / "launchd.stdout.log"),
            ("stderr", self.log_dir / "launchd.stderr.log"),
        ]
        
        for name, path in log_files:
            if log_type == "all" or log_type == name:
                if path.exists():
                    try:
                        logs[name] = path.read_text()
                    except Exception as e:
                        logs[name] = f"Error reading log: {e}"
                else:
                    logs[name] = f"Log file not found: {path}"
        
        return logs
