"""
Unit tests for GooglePhotosSync class.

These tests verify the Python interface functionality without requiring
actual rclone/fswatch dependencies.
"""

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch, PropertyMock

import pytest


class TestGooglePhotosSync:
    """Test suite for GooglePhotosSync class."""

    def test_init_with_defaults(self):
        """Test initialization with default paths."""
        from tools.google_photos_sync import GooglePhotosSync
        
        sync = GooglePhotosSync()
        
        # Check default paths exist
        assert sync.tool_dir.exists()
        assert str(sync.watch_dir).endswith("Photos_Sync/Watch")
        assert str(sync.uploaded_dir).endswith("Photos_Sync/Uploaded")
        assert str(sync.log_dir).endswith("Photos_Sync/Logs")
        
        # Check script paths
        assert sync.setup_script.name == "setup.sh"
        assert sync.start_script.name == "start_watch.sh"
        assert sync.worker_script.name == "upload_worker.sh"
        assert sync.plist_file.name == "com.local.google-photos-sync.plist"

    def test_init_with_custom_paths(self):
        """Test initialization with custom paths."""
        from tools.google_photos_sync import GooglePhotosSync
        
        with tempfile.TemporaryDirectory() as tmpdir:
            custom_watch = Path(tmpdir) / "custom_watch"
            custom_uploaded = Path(tmpdir) / "custom_uploaded"
            custom_log = Path(tmpdir) / "custom_log"
            
            sync = GooglePhotosSync(
                watch_dir=custom_watch,
                uploaded_dir=custom_uploaded,
                log_dir=custom_log,
            )
            
            assert sync.watch_dir == custom_watch
            assert sync.uploaded_dir == custom_uploaded
            assert sync.log_dir == custom_log

    def test_get_status_returns_dict(self):
        """Test that get_status returns a dictionary with expected keys."""
        from tools.google_photos_sync import GooglePhotosSync
        
        sync = GooglePhotosSync()
        status = sync.get_status()
        
        assert isinstance(status, dict)
        assert "watch_dir" in status
        assert "uploaded_dir" in status
        assert "log_dir" in status
        assert "scripts" in status
        assert "directories" in status
        assert "rclone_installed" in status
        assert "fswatch_installed" in status

    def test_get_status_scripts_check(self):
        """Test that get_status checks for script existence."""
        from tools.google_photos_sync import GooglePhotosSync
        
        sync = GooglePhotosSync()
        status = sync.get_status()
        
        # All scripts should exist
        assert status["scripts"]["setup"] == True
        assert status["scripts"]["start"] == True
        assert status["scripts"]["worker"] == True
        assert status["scripts"]["plist"] == True

    def test_get_status_directories_check(self):
        """Test that get_status checks directory existence."""
        from tools.google_photos_sync import GooglePhotosSync
        
        with tempfile.TemporaryDirectory() as tmpdir:
            watch_dir = Path(tmpdir) / "Watch"
            uploaded_dir = Path(tmpdir) / "Uploaded"
            log_dir = Path(tmpdir) / "Logs"
            
            # Create some directories
            watch_dir.mkdir()
            uploaded_dir.mkdir()
            
            sync = GooglePhotosSync(
                watch_dir=watch_dir,
                uploaded_dir=uploaded_dir,
                log_dir=log_dir,
            )
            
            status = sync.get_status()
            
            # Check directory status
            assert status["directories"]["watch"] == True
            assert status["directories"]["uploaded"] == True
            assert status["directories"]["log"] == False  # Not created

    @patch("subprocess.run")
    def test_get_status_rclone_check(self, mock_run):
        """Test that get_status checks for rclone installation."""
        from tools.google_photos_sync import GooglePhotosSync
        
        # Mock rclone being installed
        mock_run.return_value = MagicMock(returncode=0)
        
        sync = GooglePhotosSync()
        status = sync.get_status()
        
        # rclone should be detected as installed
        assert status["rclone_installed"] == True
        
        # Verify which was called (check in call args list)
        calls = [call[0][0] for call in mock_run.call_args_list]
        assert ["which", "rclone"] in calls

    @patch("subprocess.run")
    def test_get_status_fswatch_check(self, mock_run):
        """Test that get_status checks for fswatch installation."""
        from tools.google_photos_sync import GooglePhotosSync
        
        # Mock fswatch being installed
        mock_run.return_value = MagicMock(returncode=0)
        
        sync = GooglePhotosSync()
        status = sync.get_status()
        
        # fswatch should be detected as installed
        assert status["fswatch_installed"] == True
        
        # Verify which was called
        mock_run.assert_called_with(["which", "fswatch"], capture_output=True, check=True)

    @patch("subprocess.run")
    def test_upload_file_success(self, mock_run):
        """Test successful file upload."""
        from tools.google_photos_sync import GooglePhotosSync
        
        # Mock successful subprocess call
        mock_run.return_value = MagicMock(returncode=0, stdout="Upload successful", stderr="")
        
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            tmp.write(b"test content")
            tmp_path = Path(tmp.name)
        
        try:
            sync = GooglePhotosSync()
            result = sync.upload_file(tmp_path)
            
            assert result == True
            mock_run.assert_called_once()
            
            # Check the command includes the worker script
            call_args = mock_run.call_args[0][0]
            assert str(sync.worker_script) in str(call_args[0])
        finally:
            tmp_path.unlink()

    @patch("subprocess.run")
    def test_upload_file_failure(self, mock_run):
        """Test failed file upload."""
        from tools.google_photos_sync import GooglePhotosSync
        import subprocess
        
        # Mock failed subprocess call
        mock_run.side_effect = subprocess.CalledProcessError(1, "test")
        
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            tmp.write(b"test content")
            tmp_path = Path(tmp.name)
        
        try:
            sync = GooglePhotosSync()
            result = sync.upload_file(tmp_path)
            
            assert result == False
        finally:
            tmp_path.unlink()

    @patch("subprocess.run")
    def test_upload_file_nonexistent(self, mock_run):
        """Test upload with non-existent file."""
        from tools.google_photos_sync import GooglePhotosSync
        
        sync = GooglePhotosSync()
        nonexistent = Path("/nonexistent/file.jpg")
        
        result = sync.upload_file(nonexistent)
        
        assert result == False
        # subprocess.run should not be called for non-existent file
        mock_run.assert_not_called()

    def test_start_monitor_returns_process(self):
        """Test that start_monitor returns a Popen object."""
        from tools.google_photos_sync import GooglePhotosSync
        import subprocess
        
        with patch("subprocess.Popen") as mock_popen:
            mock_process = MagicMock()
            mock_popen.return_value = mock_process
            
            sync = GooglePhotosSync()
            process = sync.start_monitor()
            
            assert process == mock_process
            mock_popen.assert_called_once()

    def test_stop_monitor_success(self):
        """Test successful monitor stop."""
        from tools.google_photos_sync import GooglePhotosSync
        import subprocess
        
        mock_process = MagicMock()
        mock_process.terminate = MagicMock()
        mock_process.wait = MagicMock()
        
        sync = GooglePhotosSync()
        
        result = sync.stop_monitor(mock_process)
        
        assert result == True
        mock_process.terminate.assert_called_once()
        mock_process.wait.assert_called_once_with(timeout=5)

    def test_stop_monitor_timeout(self):
        """Test monitor stop with timeout."""
        from tools.google_photos_sync import GooglePhotosSync
        import subprocess
        
        mock_process = MagicMock()
        mock_process.terminate = MagicMock(side_effect=subprocess.TimeoutExpired("test", 5))
        mock_process.wait = MagicMock()
        mock_process.kill = MagicMock()
        
        sync = GooglePhotosSync()
        
        result = sync.stop_monitor(mock_process)
        
        assert result == True
        mock_process.kill.assert_called_once()

    def test_package_metadata(self):
        """Test that package metadata is defined."""
        from tools.google_photos_sync import __version__, __author__, __description__
        
        assert __version__ == "1.0.0"
        assert __author__ == "Alex Broley"
        assert "Google Photos Sync" in __description__


class TestDefaultPaths:
    """Test default path constants."""

    def test_default_tool_dir(self):
        """Test DEFAULT_TOOL_DIR points to package directory."""
        from tools.google_photos_sync import DEFAULT_TOOL_DIR
        
        assert DEFAULT_TOOL_DIR.exists()
        assert (DEFAULT_TOOL_DIR / "cli.py").exists()

    def test_default_watch_dir(self):
        """Test DEFAULT_WATCH_DIR structure."""
        from tools.google_photos_sync import DEFAULT_WATCH_DIR
        
        assert str(DEFAULT_WATCH_DIR).endswith("Photos_Sync/Watch")

    def test_default_uploaded_dir(self):
        """Test DEFAULT_UPLOADED_DIR structure."""
        from tools.google_photos_sync import DEFAULT_UPLOADED_DIR
        
        assert str(DEFAULT_UPLOADED_DIR).endswith("Photos_Sync/Uploaded")

    def test_default_log_dir(self):
        """Test DEFAULT_LOG_DIR structure."""
        from tools.google_photos_sync import DEFAULT_LOG_DIR
        
        assert str(DEFAULT_LOG_DIR).endswith("Photos_Sync/Logs")
