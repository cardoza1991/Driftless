#!/usr/bin/env bash
# watch-contract.sh
# Watches api-contract/contract.yaml for writes from ANY process (including
# Stephen's Claude Code session) and auto-runs sync-backend.sh.
#
# Usage:
#   ./scripts/watch-contract.sh           # foreground (Ctrl+C to stop)
#   ./scripts/watch-contract.sh --daemon  # background (logs to sync.log)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACT="$REPO_ROOT/api-contract/contract.yaml"
SYNC="$SCRIPT_DIR/sync-backend.sh"
LOG_FILE="$REPO_ROOT/scripts/sync.log"
DAEMON=false

for arg in "$@"; do
  case $arg in --daemon) DAEMON=true ;; esac
done

# ---- Load Discord notifier ---------------------------------------------
source "$SCRIPT_DIR/notify.sh"

if ! command -v inotifywait &>/dev/null; then
  echo "Installing inotify-tools..."
  sudo apt-get install -y inotify-tools &>/dev/null || {
    echo "ERROR: could not install inotify-tools."
    echo "Run: sudo apt install inotify-tools"
    notify_failure "watch-contract" "inotify-tools not installed."
    exit 1
  }
fi

run_watcher() {
  echo "[watch-contract] started — watching $CONTRACT"
  echo "[watch-contract] any write to contract.yaml triggers auto-sync"
  echo "[watch-contract] log: $LOG_FILE"

  notify_start "watch-contract" "$CONTRACT"

  inotifywait -m -e close_write -e moved_to \
    --format '%T %f' --timefmt '%H:%M:%S' \
    "$(dirname "$CONTRACT")" |
  while read -r TIME FILE; do
    if [[ "$FILE" == "$(basename "$CONTRACT")" ]]; then
      echo "[watch-contract] $TIME — contract.yaml changed — syncing..."

      # Detect who changed it via git (best effort)
      AUTHOR=$(git -C "$REPO_ROOT" log -1 --pretty=format:'%an' 2>/dev/null || echo "unknown")
      notify_contract_change "$AUTHOR"

      "$SYNC" 2>&1 | tee -a "$LOG_FILE"
    fi
  done
}

if [[ "$DAEMON" == "true" ]]; then
  nohup bash -c "$(declare -f run_watcher); run_watcher" \
    >> "$LOG_FILE" 2>&1 &
  echo "[watch-contract] daemon started (PID $!)"
  echo "[watch-contract] tail -f $LOG_FILE  to follow"
else
  run_watcher
fi
