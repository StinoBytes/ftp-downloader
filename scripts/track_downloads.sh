#!/bin/bash

# Function to register a downloaded file in the database
register_download() {

  # Validate input parameters
  if [ "$#" -ne 4 ]; then
    echo "[$(date)] Error: Expected 4 parameters, got $#"
    echo "Usage: register_download filename remote_path server_filepath file_path"
    return 1
  fi

  local filename="$1"
  local remote_path="$2"
  local server_filepath="$3"
  local file_path="$4"
  local temp_file="${file_path}.temp"

  # Setup cleanup trap (remove temp file on premature exit)
  trap 'rm -f "${temp_file}"' EXIT

  # Check if file exists
  if [ ! -f "$file_path" ]; then
    echo "[$(date)] Error: File not found: $file_path"
    return 1
  fi

  # Get file size
  if ! size=$(stat -c %s "$file_path" 2>/dev/null); then
    echo "[$(date)] Error: Could not get file size for: $file_path"
    return 1
  fi

  # Calculate checksum
  if ! checksum=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1); then
    echo "[$(date)] Error: Could not calculate checksum for: $file_path"
    return 1
  fi

  # Create CSV data
  csv_data=$(printf "%s,%s,%s,%s,%s\n" \
    "${filename}" \
    "${remote_path}" \
    "${server_filepath}" \
    "${size}" \
    "${checksum}")

  # Temporary SQL file with CSV data embedded
  sql_commands=$(
    cat <<EOF
.bail on
.mode csv
CREATE TEMP TABLE temp_import(filename,remote_path,server_filepath,size,checksum);
.import '${temp_file}' temp_import
INSERT OR IGNORE INTO downloaded_files (filename, remote_path, server_filepath, size, checksum)
SELECT filename, remote_path, server_filepath, CAST(size AS INTEGER), checksum FROM temp_import;
DROP TABLE temp_import;
EOF
  )

  # Save CSV to temporary file
  if ! echo "$csv_data" >"${temp_file}"; then
    echo "[$(date)] Error: Could not create temporary file: ${temp_file}"
    return 1
  fi

  # Check if database exists
  if [ ! -f "/db/downloads.db" ]; then
    echo "[$(date)] Error: Database file not found: /db/downloads.db"
    return 1
  fi

  # Execute SQL commands
  if echo "$sql_commands" | sqlite3 /db/downloads.db; then
    echo "[$(date)] Registered download: $filename from $remote_path ($size bytes, MD5: $checksum)"
    return 0
  else
    echo "[$(date)] Error: Failed to register download in database"
    return 1
  fi
}
