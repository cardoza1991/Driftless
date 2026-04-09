#!/usr/bin/env bash
# watch-frontend.sh
# Watches Stephen's frontend code for changes and auto-syncs the backend.
#
# Usage:
#   ./scripts/watch-frontend.sh           # foreground
#   ./scripts/watch-frontend.sh --daemon  # background (logs to sync.log)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$REPO_ROOT/scripts/sync.log"
SYNC="$SCRIPT_DIR/sync-backend.sh"
DAEMON=false

for arg in "$@"; do
  case $arg in --daemon) DAEMON=true ;; esac
done

# ---- Load Discord notifier ---------------------------------------------
source "$SCRIPT_DIR/notify.sh"

if ! command -v inotifywait &>/dev/null; then
  echo "Installing inotify-tools..."
  sudo apt-get install -y inotify-tools &>/dev/null || {
    echo "ERROR: sudo apt install inotify-tools"
    notify_failure "watch-frontend" "inotify-tools not installed."
    exit 1
  }
fi

WATCH_DIRS=()
for candidate in frontend web client app; do
  [[ -d "$REPO_ROOT/$candidate" ]] && WATCH_DIRS+=("$REPO_ROOT/$candidate")
done

wait_for_frontend() {
  echo "[watch-frontend] waiting for Stephen to create a frontend directory..."
  notify_start "watch-frontend" "waiting for frontend/ to appear..."
  while true; do
    for candidate in frontend web client app; do
      if [[ -d "$REPO_ROOT/$candidate" ]]; then
        echo "[watch-frontend] found $REPO_ROOT/$candidate — starting watch"
        return
      fi
    done
    sleep 5
  done
}

run_watcher() {
  if [[ ${#WATCH_DIRS[@]} -eq 0 ]]; then
    wait_for_frontend
    for candidate in frontend web client app; do
      [[ -d "$REPO_ROOT/$candidate" ]] && WATCH_DIRS+=("$REPO_ROOT/$candidate")
    done
  fi

  echo "[watch-frontend] watching: ${WATCH_DIRS[*]}"
  echo "[watch-frontend] triggers on: .js .ts .jsx .tsx .vue .svelte"
  echo "[watch-frontend] log: $LOG_FILE"

  notify_start "watch-frontend" "${WATCH_DIRS[*]}"

  LAST_SYNC=0
  DEBOUNCE=3

  inotifywait -m -r -e close_write -e moved_to \
    --format '%T %w%f' --timefmt '%H:%M:%S' \
    "${WATCH_DIRS[@]}" 2>/dev/null |
  while read -r TIME FILEPATH; do
    case "$FILEPATH" in
      *.js|*.ts|*.jsx|*.tsx|*.vue|*.svelte|*.html) ;;
      *) continue ;;
    esac

    [[ "$FILEPATH" == *node_modules* ]] && continue

    NOW=$(date +%s)
    SINCE=$(( NOW - LAST_SYNC ))
    if (( SINCE >= DEBOUNCE )); then
      LAST_SYNC=$NOW
      echo "[watch-frontend] $TIME — ${FILEPATH##*/} saved — syncing backend..."
      "$SYNC" 2>&1 | tail -5
    fi
  done
}

if [[ "$DAEMON" == "true" ]]; then
  nohup bash -c "
    REPO_ROOT='$REPO_ROOT'
    LOG_FILE='$LOG_FILE'
    SYNC='$SYNC'
    DAEMON=false
    WATCH_DIRS=()
    $(declare -f wait_for_frontend run_watcher)
    source '$SCRIPT_DIR/notify.sh'
    run_watcher
  " >> "$LOG_FILE" 2>&1 &
  echo "[watch-frontend] daemon started (PID $!)"
  echo "[watch-frontend] tail -f $LOG_FILE  to follow"
else
  run_watcher
fi
