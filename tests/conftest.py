"""
Pytest configuration for google-clients project.
"""

import pytest


# Define test markers
@pytest.fixture
def temp_photos_sync_dir(tmp_path):
    """Create a temporary Photos_Sync directory structure for testing."""
    watch_dir = tmp_path / "Watch"
    uploaded_dir = tmp_path / "Uploaded"
    logs_dir = tmp_path / "Logs"
    
    watch_dir.mkdir()
    uploaded_dir.mkdir()
    logs_dir.mkdir()
    
    return tmp_path


@pytest.fixture
def mock_rclone_config(tmp_path):
    """Create a mock rclone config file for testing."""
    config_dir = tmp_path / ".config" / "rclone"
    config_dir.mkdir(parents=True)
    
    config_file = config_dir / "rclone.conf"
    config_file.write_text("[test_remote]\ntype = google photos\ntoken = test_token\n")
    
    return config_file
