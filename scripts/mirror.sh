#!/bin/bash
set -e

echo "Starting download process at $(date)"

FTP_TARGET="/data"

check_time_window() {
  # Time window check
  CURRENT_HOUR=$(date +%H)
  if [[ $DOWNLOAD_HOURS == *-* ]]; then
    START_HOUR=$(echo $DOWNLOAD_HOURS | cut -d'-' -f1)
    END_HOUR=$(echo $DOWNLOAD_HOURS | cut -d'-' -f2)

    if [ $START_HOUR -eq $END_HOUR ]; then
      return
    fi

    if [ $START_HOUR -lt $END_HOUR ]; then
      if [ $CURRENT_HOUR -lt $START_HOUR ] || [ $CURRENT_HOUR -ge $END_HOUR ]; then
        echo "Current hour ($CURRENT_HOUR) is outside download window ($DOWNLOAD_HOURS). Exiting."
        exit 0
      fi
    else
      if [ $CURRENT_HOUR -lt $START_HOUR ] && [ $CURRENT_HOUR -ge $END_HOUR ]; then
        echo "Current hour ($CURRENT_HOUR) is outside download window ($DOWNLOAD_HOURS). Exiting."
        exit 0
      fi
    fi
  fi
}

# Check every minute if we are within the download window
{
  while true; do
    check_time_window
    sleep 60
  done
} &

# Create target directories
mkdir -p "$FTP_TARGET/active"
mkdir -p "$FTP_TARGET/finished"
chmod -R 777 "$FTP_TARGET" # Ensure permissions are correct

# Source the track_downloads script for the register_download function
source /app/track_downloads.sh

# Function to extract server path from lftp-transfer.log
get_server_path() {
  local FILE="$1"
  local filename=$(basename "$FILE")
  local rel_path=$(dirname "${FILE#$FTP_TARGET/active/}")

  # Get the server path from lftp-transfer.log if it exists
  if [ -f "$FTP_TARGET/lftp-transfer.log" ]; then
    # Extract exact server path from the log, stripping ftp://user@host part
    server_path=$(grep -F " -> $FILE " "$FTP_TARGET/lftp-transfer.log" | head -1 | sed 's/^.*@[^/]*\(\/[^[:space:]]*\).*/\1/')

    if [ -n "$server_path" ]; then
      echo "$server_path"
      return
    fi
  fi

  # Fallback: construct path with simple space encoding
  local encoded_name=$(echo "$filename" | sed 's/ /%20/g')
  echo "/ROMS/$rel_path/$encoded_name"
}

# Function to process a completed file
process_completed_file() {
  local FILE="$1"
  local LOG="$FTP_TARGET/process.log"

  if [ -f "$FILE" ]; then
    # Get file information
    local filename=$(basename "$FILE")
    local dir_path=$(dirname "$FILE")

    # Skip if this is a temporary file
    if [[ "$filename" == *.lftp-pget-status ]]; then
      return
    fi

    # Check if file is still downloading
    status_file="${FILE}.lftp-pget-status"
    if [ -f "$status_file" ]; then
      echo "File still downloading: $filename" >>"$LOG"
      return
    fi

    echo "Processing: $FILE" >>"$LOG"

    # Extract the relative path
    local relative_path=${dir_path#$FTP_TARGET/active/}

    # Get the exact server path from the transfer log
    local server_filepath=$(get_server_path "$FILE")
    echo "Server filepath: $server_filepath" >>"$LOG"

    # Create destination directory structure in finished folder
    local target_dir="$FTP_TARGET/finished/$relative_path"
    mkdir -p "$target_dir"

    # Move file to finished directory
    if mv "$FILE" "$target_dir/$filename"; then
      echo "[$(date)] Moved: $filename to $target_dir" >>"$LOG"

      # Register in database
      if register_download "$filename" "$relative_path" "$server_filepath" "$target_dir/$filename"; then
        echo "[$(date)] Processed: $filename to $target_dir" >>"$LOG"
      else
        echo "[$(date)] Failed to register in database: $filename" >>"$LOG"
      fi
    else
      echo "[$(date)] Failed to move file: $filename" >>"$LOG"
    fi
  fi
}

# Create exclude list directly in the FTP_TARGET directory
>"$FTP_TARGET/exclude-list.txt"
echo "Building list of excluded files..." >"$FTP_TARGET/download.log"

# Get filename and remote_path from the database for the exclude list
sqlite3 /db/downloads.db "SELECT remote_path, filename FROM downloaded_files;" \
  | while IFS='|' read -r remote_path filename; do
    # Create a pattern in the format that LFTP expects (relative path with spaces)
    clean_ftp_source="${FTP_SOURCE#/}"
    pattern="${remote_path#${clean_ftp_source}/}/${filename}"
    echo "$pattern" >>"$FTP_TARGET/exclude-list.txt"
    echo "Added exclusion: $pattern" >>"$FTP_TARGET/download.log"
  done

# Verify the exclude list was created correctly
if [ -s "$FTP_TARGET/exclude-list.txt" ]; then
  echo "Found $(wc -l <"$FTP_TARGET/exclude-list.txt") already downloaded files" >>"$FTP_TARGET/download.log"
else
  echo "Warning: Exclude list is empty!" >>"$FTP_TARGET/download.log"
fi

# Start background file processor
{
  echo "[$(date)] Background file processor started" >"$FTP_TARGET/process.log"

  while true; do
    # Find completed files and process them
    find "$FTP_TARGET/active" -type f -not -name "*.lftp-pget-status" -print0 \
      | while IFS= read -r -d '' file; do
        process_completed_file "$file"
      done

    # Sleep before checking again
    sleep 10
  done
} &

BACKGROUND_PID=$!

# Create a simple LFTP script that uses mirror but excludes already downloaded files
MIRROR_SCRIPT="$FTP_TARGET/mirror-script.lftp"
cat >"$MIRROR_SCRIPT" <<EOF
# LFTP configuration
set ssl:verify-certificate no
open -u "$FTP_USER","$FTP_PASS" "$FTP_HOST"
set net:timeout 60
set net:max-retries 3
set xfer:log true
set pget:min-chunk-size 1M
set xfer:log-file "$FTP_TARGET/lftp-transfer.log"

# Set parallel download parameters (2 files * 2 segments = 4 connections total)
set mirror:parallel-transfer-count 2
set mirror:use-pget-n 2

# Debugging
# debug 3
echo "Using exclusion list from $FTP_TARGET/exclude-list.txt"

# Run mirror with exclude list
mirror -v --continue --exclude-glob-from="$FTP_TARGET/exclude-list.txt" --loop --use-cache "$FTP_SOURCE" "$FTP_TARGET/active/${FTP_SOURCE#/}"

EOF

echo "Starting LFTP mirror operation..." >>"$FTP_TARGET/download.log"

# Run the LFTP script with a timeout
timeout 6h lftp -f "$MIRROR_SCRIPT"
LFTP_EXIT=$?

echo "LFTP mirror completed with exit code $LFTP_EXIT" >>"$FTP_TARGET/download.log"

# Kill the background process
kill $BACKGROUND_PID 2>/dev/null || true

# Final processing of any remaining files
echo "Final pass to process any remaining files..." >>"$FTP_TARGET/download.log"
find "$FTP_TARGET/active" -type f -not -name "*.lftp-pget-status" -print0 \
  | while IFS= read -r -d '' file; do
    process_completed_file "$file"
  done

# Remove empty directories
find "$FTP_TARGET/active" -type d -empty -delete 2>/dev/null || true

# Handle LFTP exit codes
if [ $LFTP_EXIT -ne 0 ] && [ $LFTP_EXIT -ne 124 ]; then
  echo "LFTP error! Exit code: $LFTP_EXIT" >>"$FTP_TARGET/download.log"
  # Exit code 124 means timeout was reached, which is expected
  if [ $LFTP_EXIT -ne 124 ]; then
    exit $LFTP_EXIT
  fi
fi

echo "Download process completed at $(date)" >>"$FTP_TARGET/download.log"
echo "Download process completed at $(date)"
