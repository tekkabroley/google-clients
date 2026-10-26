"""
Tests specifically for the plist file to debug path issues.
"""

from pathlib import Path

import pytest


def test_plist_file_exists():
    """Test that plist file exists and can be read."""
    plist_path = Path(__file__).parent.parent.parent / "tools" / "google_photos_sync" / "com.local.google-photos-sync.plist"
    plist_path = plist_path.resolve()
    
    print(f"\nDEBUG: plist_path = {plist_path}")
    print(f"DEBUG: plist_path.exists() = {plist_path.exists()}")
    
    assert plist_path.exists(), f"plist file not found: {plist_path}"
    
    content = plist_path.read_text()
    print(f"DEBUG: Read {len(content)} characters from plist")
    
    assert len(content) > 0
    assert "com.local.google-photos-sync" in content


def test_plist_has_program():
    """Test that plist has Program key."""
    plist_path = Path(__file__).parent.parent.parent / "tools" / "google_photos_sync" / "com.local.google-photos-sync.plist"
    content = plist_path.read_text()
    
    assert "<key>Program</key>" in content
    assert "start_watch.sh" in content


def test_plist_has_run_at_load():
    """Test that plist runs at load."""
    plist_path = Path(__file__).parent.parent.parent / "tools" / "google_photos_sync" / "com.local.google-photos-sync.plist"
    content = plist_path.read_text()
    
    assert "<key>RunAtLoad</key>" in content
    assert "<true/>" in content


def test_plist_has_keep_alive():
    """Test that plist has KeepAlive."""
    plist_path = Path(__file__).parent.parent.parent / "tools" / "google_photos_sync" / "com.local.google-photos-sync.plist"
    content = plist_path.read_text()
    
    assert "<key>KeepAlive</key>" in content
