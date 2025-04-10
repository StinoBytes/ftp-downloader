#!/bin/bash

# Function to register a downloaded file in the database
register_download() {
  local filename="$1"
  local remote_path="$2"
  local server_filepath="$3"
  local file_path="$4"

  # Check if file exists
  if [ ! -f "$file_path" ]; then
    echo "[$(date)] Error: File not found: $file_path"
    return 1
  fi

  size=$(stat -c %s "$file_path")
  checksum=$(md5sum "$file_path" | cut -d' ' -f1)

  # Create CSV data
  csv_data=$(printf "%s,%s,%s,%s,%s\n" "$filename" "$remote_path" "$server_filepath" "$size" "$checksum")

  # Temporary SQL file with CSV data embedded
  sql_commands=$(
    cat <<EOF
.bail on
.mode csv
CREATE TEMP TABLE temp_import(filename,remote_path,server_filepath,size,checksum);
.import '${file_path}.temp' temp_import
INSERT OR IGNORE INTO downloaded_files (filename, remote_path, server_filepath, size, checksum)
SELECT filename, remote_path, server_filepath, CAST(size AS INTEGER), checksum FROM temp_import;
DROP TABLE temp_import;
EOF
  )

  # Save CSV to temporary file
  echo "$csv_data" >"${file_path}.temp"

  # Execute SQL commands
  if echo "$sql_commands" | sqlite3 /db/downloads.db; then
    rm "${file_path}.temp"
    echo "[$(date)] Registered download: $filename from $remote_path ($size bytes, MD5: $checksum)"
    return 0
  else
    rm "${file_path}.temp"
    echo "[$(date)] Error: Failed to register download in database"
    return 1
  fi
}
