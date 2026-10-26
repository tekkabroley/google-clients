# System Specification: Automated Google Photos Sync

## 1. Project Objective
Create a lightweight, background-capable automation system that watches a local directory on macOS, waits for incoming image files to completely finish writing, and uploads them to Google Photos using `rclone`.

## 2. Target Environment & Constraints
*   **Operating System:** macOS Sonoma
*   **Shell:** `zsh` or `bash`
*   **Dependencies:** `rclone` (with Google Photos remote), `fswatch`
*   **Payload:** High-resolution images, specifically large 60MB+ `.ARW` (RAW) files and JPEGs.
*   **Critical Requirement:** Strict debouncing is mandatory. The script must ensure these massive files have completely finished copying from external media before attempting the `rclone` upload.

## 3. Directory Structure
The script should assume or create the following directory structure:
*   `~/Photos_Sync/Watch/` : The ingestion folder monitored by `fswatch`.
*   `~/Photos_Sync/Uploaded/` : The archive folder where files are moved *after* a successful `rclone` upload to prevent duplicate processing loops.
*   `~/Photos_Sync/Logs/` : Directory for script execution logs and rclone output.

## 4. Execution Flow
1.  `fswatch` continually monitors the `Watch` directory for new file events.
2.  Upon detecting a new file, `fswatch` pipes the absolute file path to a worker bash script.
3.  **Debounce Loop:** The worker script checks the file size in bytes, sleeps for 3 seconds, and checks again. It repeats this loop until the file size remains completely unchanged between checks.
4.  **Upload:** Once the file size is stable, the script executes `rclone copy` targeting a specific Google Photos album (e.g., `remote:album/AutoSync`).
5.  **Cleanup:** If `rclone` exits with a success code (`0`), the script moves the local file from `Watch/` to `Uploaded/`. If it fails, the file remains in `Watch/` and the error is logged.

## 5. Tasks for the Coding Agent
Please generate the following deliverables:
1.  **Dependency Setup Instructions:** Brief terminal commands to install `fswatch` and `rclone` via Homebrew, plus the specific `rclone config` steps required for the Google Photos API.
2.  **The Worker Script (`upload_worker.sh`):** The bash/zsh script containing the file size debouncing loop, the `rclone` execution, file relocation, and basic echo/append logging.
3.  **The Monitor Script (`start_watch.sh`):** The exact `fswatch` command structure (using `-0` and `xargs -0` to handle spaces in filenames) that pipes newly created files into the worker script.
4.  **Background Execution (Optional):** Provide a standard macOS `launchd` `.plist` file so this `fswatch` monitor can start automatically on login without requiring an open terminal window.