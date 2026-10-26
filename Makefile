# Makefile for google-clients project

.PHONY: help install test lint clean

# Default target
help:
	@echo "Google Clients Project - Available Commands"
	@echo "=========================================="
	@echo ""
	@echo "  make install    - Install the package and dependencies"
	@echo "  make test       - Run all tests"
	@echo "  make test-unit  - Run only unit tests"
	@echo "  make test-integ - Run only integration tests"
	@echo "  make test-cov   - Run tests with coverage"
	@echo "  make lint       - Run code style checks"
	@echo "  make clean      - Clean up build artifacts"
	@echo ""

# Install the package
install:
	poetry install

# Run all tests
test:
	poetry run pytest tests/ -v

# Run only unit tests
test-unit:
	poetry run pytest tests/google_photos_sync/test_google_photos_sync.py -v

# Run only integration tests
test-integ:
	poetry run pytest tests/google_photos_sync/test_bash_scripts.py -v

# Run tests with coverage
test-cov:
	poetry run pytest tests/ --cov=tools/google_photos_sync --cov=google_drive_client --cov-report=term-missing --cov-report=html

# Run linting
lint:
	# Add your linting commands here
	# e.g., poetry run flake8 .
	# e.g., poetry run black --check .
	@echo "Linting not configured. Add your linter (flake8, black, etc.) to pyproject.toml."

# Clean up
clean:
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf htmlcov
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

# Additional targets for Google Photos Sync
.PHONY: gphotos-setup gphotos-start gphotos-test

# Setup Google Photos Sync
gphotos-setup:
	./tools/google_photos_sync/setup.sh

# Start Google Photos Sync monitor
gphotos-start:
	./tools/google_photos_sync/start_watch.sh

# Test Google Photos Sync
gphotos-test:
	poetry run pytest tests/google_photos_sync/ -v
