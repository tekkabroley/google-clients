#!/bin/bash

echo "Running create command..."
output=$(poetry run python3 -m google_drive_client.cli create "$test_sheet_name" "$test_sheet_id" 2>&1)
exit_code=$?

echo "$output"

if [ $exit_code -eq 0 ]; then
    echo "Command succeeded"
    
    # Extract the file ID from output (assuming it's printed)
    file_id=$(echo "$output" | grep -o '[a-zA-Z0-9_-]\{25,\}')
    
    if [ ! -z "$file_id" ]; then
        echo "File ID: $file_id"
        echo "Check here: https://docs.google.com/spreadsheets/d/$file_id"
    fi
else
    echo "Command failed with exit code $exit_code"
    exit 1
fi