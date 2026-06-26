#!/bin/bash
# =====================================================================
# NEUROSCIENCE APP - AUTOMATIC DATABASE BACKUP SCRIPT (CRON)
# =====================================================================

# Load environment variables
ENV_FILE="/app/.env.production"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

# Ensure database URL is available
if [ -z "$DATABASE_URL" ]; then
    echo "Error: DATABASE_URL is not set in $ENV_FILE"
    exit 1
fi

BACKUP_DIR="/var/backups/neuroscience"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql.gz"

echo "Starting database backup..."

# Ensure PostgreSQL client is installed
if ! [ -x "$(command -v pg_dump)" ]; then
    echo "Installing postgresql-client..."
    sudo apt-get update && sudo apt-get install -y postgresql-client
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Perform backup and compress it
pg_dump "$DATABASE_URL" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: $BACKUP_FILE"
else
    echo "Error: Database backup failed!"
    exit 1
fi

# Delete backups older than 7 days to preserve disk space
find "$BACKUP_DIR" -type f -name "db_backup_*.sql.gz" -mtime +7 -delete

echo "Old backups cleaned up."
