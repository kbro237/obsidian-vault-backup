# AGENTS.md

## What this repo is

A single-shell-script backup utility for an Obsidian vault at `/Users/keith/Local/Obsidian/Notebook`. It creates incremental tar.gz snapshots with rotation.

## Running

```sh
bash obsidian_backup.sh
```

No install step, no dependencies beyond `tar`. If `pigz` is available, it's used automatically for faster compression.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `MAX_BACKUPS` | 7 | Number of `.tar.gz` files to keep (oldest deleted first) |
| `FORCE_FULL_BACKUP` | 0 | Set to `1` to discard incremental state and force a full backup |
| `USE_PIGZ` | 1 | Set to `0` to skip pigz even if installed |

## How incremental backups work

The script uses `tar --listed-incremental` with a `.snar` state file (`Notebook.snar`). Deleting that file forces a full backup. The script never deletes it on its own unless `FORCE_FULL_BACKUP=1`.

## Excluded paths

- `.copilot-index/` — Copilot search index
- `.trash/` — Obsidian's trash folder

## Output

- Backup archives: `Notebook-YYYYMMDD-HHMMSS.tar.gz`
- Log: `obsidian_backup.log`