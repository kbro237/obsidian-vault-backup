#!/usr/bin/env bash
set -euo pipefail

# Configuration
SOURCE="/Users/keith/Local/Obsidian/Notebook"
DEST="/Users/keith/Documents/Backup Misc/obsidian-vault-backup"
BASE_NAME="Notebook"

# Incremental backup support
SNAR="$DEST/${BASE_NAME}.snar"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="$DEST/${BASE_NAME}-${TIMESTAMP}.tar.gz"

# Retention policy
MAX_BACKUPS="${MAX_BACKUPS:-7}"
FORCE_FULL_BACKUP="${FORCE_FULL_BACKUP:-0}"
USE_PIGZ="${USE_PIGZ:-1}"

# Validate integer env vars
for var in MAX_BACKUPS USE_PIGZ; do
  if ! [[ "${!var}" =~ ^[0-9]+$ ]]; then
    echo "Error: $var must be a non-negative integer, got '${!var}'" >&2
    exit 1
  fi
done

# Validate source exists
if [ ! -d "$SOURCE" ]; then
  echo "Error: source directory does not exist: $SOURCE" >&2
  exit 1
fi

# Ensure destination exists
mkdir -p "$DEST"

# Remove partial backup file on error
cleanup() {
  if [ -f "$BACKUP_FILE" ]; then
    rm -f "$BACKUP_FILE"
    echo "Removed partial backup: $BACKUP_FILE" >> "$DEST/obsidian_backup.log" 2>&1
  fi
}
trap cleanup ERR

# Optionally force a full backup by removing the snar state
if [ "$FORCE_FULL_BACKUP" = "1" ]; then
  rm -f "$SNAR"
fi

# Run the backup
START_TIME=$(date +%s)

EXCLUDES=(
  "--exclude=${BASE_NAME}/.copilot-index"
  "--exclude=${BASE_NAME}/.trash"
)

if command -v pigz >/dev/null && [ "$USE_PIGZ" -ne 0 ]; then
  tar -cf - \
    -C "$(dirname "$SOURCE")" \
    "${BASE_NAME}" \
    "${EXCLUDES[@]}" \
    --listed-incremental="$SNAR" \
  | pigz -9 > "$BACKUP_FILE"
else
  tar -czf "$BACKUP_FILE" \
    -C "$(dirname "$SOURCE")" \
    "${BASE_NAME}" \
    "${EXCLUDES[@]}" \
    --listed-incremental="$SNAR"
fi

# Backup succeeded — disable cleanup trap
trap - ERR

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "Backup created: $BACKUP_FILE (Elapsed: ${ELAPSED}s)" >> "$DEST/obsidian_backup.log" 2>&1

# Rotation: delete oldest backups beyond MAX_BACKUPS
# Sort by filename (which embeds the timestamp) so mtime doesn't matter
shopt -s nullglob
mapfile -t BACKUPS < <(printf '%s\n' "$DEST"/"${BASE_NAME}"-*.tar.gz | sort -r)
NUM=${#BACKUPS[@]}
if (( NUM > MAX_BACKUPS )); then
  for ((i=MAX_BACKUPS; i<NUM; i++)); do
    rm -f "${BACKUPS[$i]}"
  done
fi
unset BACKUPS

echo "Rotation complete. Total backups: $(ls -1 "$DEST"/"${BASE_NAME}"-*.tar.gz 2>/dev/null | wc -l)" >> "$DEST/obsidian_backup.log" 2>&1