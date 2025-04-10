#!/bin/bash
set -e

# Create database for tracking downloads
if [ ! -f "/db/downloads.db" ]; then
  echo "Initializing download tracking database..."
  sqlite3 /db/downloads.db "CREATE TABLE downloaded_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL,
        remote_path TEXT NOT NULL,
        server_filepath TEXT NOT NULL,
        size BIGINT,
        download_date DATETIME DEFAULT CURRENT_TIMESTAMP,
        checksum TEXT,
        UNIQUE(remote_path, filename),
        UNIQUE(server_filepath)
    );"

  echo "Database initialized."
else
  echo "Database already exists, skipping initialization."
fi
