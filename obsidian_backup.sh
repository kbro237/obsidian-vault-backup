#!/usr/bin/env bash
set -euo pipefail

# Configuration
SOURCE="/Users/keith/Local/Obsidian/Notebook"
DEST="/Users/keith/Documents/Backup Misc/obsidian-vault-backup"
BASE_NAME="Notebook"

# Incremental backup support
SNAR="$DEST/${BASE_NAME}.snar"  # tar's state file
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="$DEST/${BASE_NAME}-${TIMESTAMP}.tar.gz"

# Retention policy (adjust as you like)
MAX_BACKUPS="${MAX_BACKUPS:-7}"      # keep last N backups (order by newest)
FORCE_FULL_BACKUP="${FORCE_FULL_BACKUP:-0}"  # set to 1 to force a new full backup
USE_PIGZ="${USE_PIGZ:-1}"            # set to 0 to disable pigz

# Ensure destination exists
mkdir -p "$DEST"

# Optionally force a full backup by removing the snar state
if [ "$FORCE_FULL_BACKUP" = "1" ]; then
  rm -f "$SNAR"
fi

# Run the backup
START_TIME=$(date +%s)

EXCLUDES=(
  "--exclude=./Notebook/.copilot-index"
  "--exclude=./Notebook/.copilot-index/**"
  "--exclude=./Notebook/.trash"
  "--exclude=./Notebook/.trash/**"
)

if command -v pigz >/dev/null && [ "$USE_PIGZ" -ne 0 ]; then
  # Create an archived stream and compress with pigz for speed
  tar -cf - \
    -C "$(dirname "$SOURCE")" \
    "${BASE_NAME}" \
    "${EXCLUDES[@]}" \
    --listed-incremental="$SNAR" \
  | pigz -9 > "$BACKUP_FILE"
else
  # Pure tar.gz (no pigz)
  tar -czf "$BACKUP_FILE" \
    -C "$(dirname "$SOURCE")" \
    "$(basename "$SOURCE")" \
    "${EXCLUDES[@]}" \
    --listed-incremental="$SNAR"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "Backup created: $BACKUP_FILE (Elapsed: ${ELAPSED}s)" >> "$DEST/obsidian_backup.log" 2>&1

# Simple rotation: delete oldest backups beyond MAX_BACKUPS
shopt -s nullglob
BACKUPS=( $(ls -1t "$DEST"/"${BASE_NAME}"-*.tar.gz 2>/dev/null) )
NUM=${#BACKUPS[@]}
if (( NUM > MAX_BACKUPS )); then
  for ((i=MAX_BACKUPS; i<NUM; i++)); do
    rm -f "${BACKUPS[$i]}"
  done
fi
unset BACKUPS

echo "Rotation complete. Total backups: $(ls -1 "$DEST"/"${BASE_NAME}"-*.tar.gz 2>/dev/null | wc -l)" >> "$DEST/obsidian_backup.log" 2>&1

