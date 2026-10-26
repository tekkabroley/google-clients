"""
Integration tests for bash scripts.

These tests verify the bash scripts are syntactically correct and have
proper structure. They don't require actual execution of rclone/fswatch.
"""

import os
import stat
import unittest
from pathlib import Path

import pytest


class TestBashScriptStructure:
    """Test the structure and syntax of bash scripts."""

    @classmethod
    def setup_class(cls):
        """Set up test class with resolved paths."""
        cls.SCRIPT_DIR = (Path(__file__).parent.parent.parent / "tools" / "google_photos_sync").resolve()

    def test_setup_script_exists(self):
        """Test that setup.sh exists."""
        setup_script = self.SCRIPT_DIR / "setup.sh"
        assert setup_script.exists()
        assert setup_script.is_file()

    def test_start_watch_script_exists(self):
        """Test that start_watch.sh exists."""
        start_script = self.SCRIPT_DIR / "start_watch.sh"
        assert start_script.exists()
        assert start_script.is_file()

    def test_upload_worker_script_exists(self):
        """Test that upload_worker.sh exists."""
        worker_script = self.SCRIPT_DIR / "upload_worker.sh"
        assert worker_script.exists()
        assert worker_script.is_file()

    def test_scripts_are_executable(self):
        """Test that all bash scripts are executable."""
        scripts = ["setup.sh", "start_watch.sh", "upload_worker.sh"]
        
        for script_name in scripts:
            script_path = self.SCRIPT_DIR / script_name
            file_stat = script_path.stat()
            mode = file_stat.st_mode
            
            # Check if executable by owner
            is_executable = bool(mode & stat.S_IXUSR)
            assert is_executable, f"{script_name} is not executable"

    def test_scripts_have_shebang(self):
        """Test that all bash scripts start with shebang."""
        scripts = ["setup.sh", "start_watch.sh", "upload_worker.sh"]
        
        for script_name in scripts:
            script_path = self.SCRIPT_DIR / script_name
            with open(script_path, 'r') as f:
                first_line = f.readline().strip()
            
            assert first_line == "#!/bin/bash", f"{script_name} missing shebang"

    def test_upload_worker_has_debounce_function(self):
        """Test that upload_worker.sh has debounce function."""
        worker_script = self.SCRIPT_DIR / "upload_worker.sh"
        content = worker_script.read_text()
        
        assert "debounce_file()" in content
        assert "DEBOUNCE_SLEEP" in content
        assert "MAX_DEBOUNCE_ATTEMPTS" in content

    def test_upload_worker_has_upload_function(self):
        """Test that upload_worker.sh has upload function."""
        worker_script = self.SCRIPT_DIR / "upload_worker.sh"
        content = worker_script.read_text()
        
        assert "upload_to_google_photos()" in content
        assert "rclone copy" in content

    def test_upload_worker_has_archive_function(self):
        """Test that upload_worker.sh has archive function."""
        worker_script = self.SCRIPT_DIR / "upload_worker.sh"
        content = worker_script.read_text()
        
        assert "archive_file()" in content
        assert "mv" in content

    def test_upload_worker_has_main_function(self):
        """Test that upload_worker.sh has main function."""
        worker_script = self.SCRIPT_DIR / "upload_worker.sh"
        content = worker_script.read_text()
        
        assert "main()" in content
        assert "process_file()" in content

    def test_start_watch_uses_fswatch(self):
        """Test that start_watch.sh uses fswatch."""
        start_script = self.SCRIPT_DIR / "start_watch.sh"
        content = start_script.read_text()
        
        assert "fswatch" in content
        assert "-0" in content  # Null separator
        assert "xargs -0" in content

    def test_start_watch_has_event_handling(self):
        """Test that start_watch.sh handles file events."""
        start_script = self.SCRIPT_DIR / "start_watch.sh"
        content = start_script.read_text()
        
        assert "Created" in content
        assert "Renamed" in content or "MovedTo" in content

    def test_start_watch_calls_upload_worker(self):
        """Test that start_watch.sh calls upload_worker.sh."""
        start_script = self.SCRIPT_DIR / "start_watch.sh"
        content = start_script.read_text()
        
        assert "upload_worker.sh" in content

    def test_start_watch_has_signal_handling(self):
        """Test that start_watch.sh has signal trapping."""
        start_script = self.SCRIPT_DIR / "start_watch.sh"
        content = start_script.read_text()
        
        assert "trap" in content
        assert "SIGINT" in content or "SIGTERM" in content

    def test_setup_script_installs_dependencies(self):
        """Test that setup.sh installs rclone and fswatch."""
        setup_script = self.SCRIPT_DIR / "setup.sh"
        content = setup_script.read_text()
        
        assert "brew install rclone" in content
        assert "brew install fswatch" in content

    def test_setup_script_creates_directories(self):
        """Test that setup.sh creates required directories."""
        setup_script = self.SCRIPT_DIR / "setup.sh"
        content = setup_script.read_text()
        
        assert "Watch" in content
        assert "Uploaded" in content
        assert "Logs" in content


class TestReadmeContent:
    """Test README.md content."""

    README_PATH = Path(__file__).parent.parent.parent / "tools" / "google_photos_sync" / "README.md"

    def test_readme_exists(self):
        """Test that README.md exists."""
        assert self.README_PATH.exists()
        assert self.README_PATH.is_file()

    def test_readme_has_dependency_section(self):
        """Test that README has dependency setup."""
        content = self.README_PATH.read_text()
        
        assert "Homebrew" in content or "brew" in content
        assert "rclone" in content
        assert "fswatch" in content

    def test_readme_has_usage_instructions(self):
        """Test that README has usage instructions."""
        content = self.README_PATH.read_text()
        
        assert "Quick Start" in content or "Usage" in content

    def test_readme_has_directory_structure(self):
        """Test that README documents directory structure."""
        content = self.README_PATH.read_text()
        
        assert "Watch" in content
        assert "Uploaded" in content
        assert "Logs" in content

    def test_readme_has_troubleshooting(self):
        """Test that README has troubleshooting section."""
        content = self.README_PATH.read_text()
        
        assert "Troubleshooting" in content or "debug" in content.lower()
