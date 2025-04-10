#!/bin/bash

# Function to register a downloaded file in the database
register_download() {
  local filename="$1"
  local remote_path="$2"
  local server_filepath="$3"
  local file_path="$4"

  if [ -f "$file_path" ]; then
    size=$(stat -c %s "$file_path")
    checksum=$(md5sum "$file_path" | cut -d' ' -f1)

    sqlite3 /db/downloads.db <<EOF
      INSERT OR IGNORE INTO downloaded_files
      (filename, remote_path, server_filepath, size, checksum)
      VALUES (?, ?, ?, ?, ?);
EOF
    echo "[$(date)] Registered download: $filename from $remote_path ($size bytes, MD5: $checksum)"
    return 0
  else
    echo "[$(date)] Error: File not found: $file_path"
    return 1
  fi
}

# sqlite3 /db/downloads.db "INSERT OR IGNORE INTO downloaded_files
# (filename, remote_path, server_filepath, size, checksum)
# VALUES ('actual_filename', 'actual_remote_path', 'actual_server_filepath', actual_size, 'actual_checksum');"
