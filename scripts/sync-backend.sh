#!/usr/bin/env bash
# sync-backend.sh
# Scans frontend code for API calls, compares against the Go backend,
# and asks Claude (or configured AI backend) to implement anything missing.
# Triggered automatically by watch-frontend.sh / watch-contract.sh / cron.
#
# Usage:
#   ./scripts/sync-backend.sh              # normal run
#   ./scripts/sync-backend.sh --dry-run    # describe changes without writing files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND="$REPO_ROOT/src"
LOG_FILE="$REPO_ROOT/scripts/sync.log"
HASH_FILE="$REPO_ROOT/scripts/.frontend.sha"
DRY_RUN=false

for arg in "$@"; do
  case $arg in --dry-run) DRY_RUN=true ;; esac
done

# ---- Load Discord notifier ---------------------------------------------
source "$SCRIPT_DIR/notify.sh"

# ---- Check AI backend --------------------------------------------------
if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found." >&2
  notify_failure "sync-backend" "'claude' CLI not found on PATH."
  exit 1
fi

# ---- Find frontend code ------------------------------------------------
FRONTEND_DIR=""
for candidate in frontend web client app; do
  if [[ -d "$REPO_ROOT/$candidate" ]]; then
    FRONTEND_DIR="$REPO_ROOT/$candidate"
    break
  fi
done

if [[ -z "$FRONTEND_DIR" ]]; then
  echo "[sync-backend] no frontend directory found yet — nothing to sync"
  exit 0
fi

# ---- Hash check --------------------------------------------------------
CURRENT_HASH=$(find "$FRONTEND_DIR" \
  -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \
             -o -name "*.vue" -o -name "*.svelte" -o -name "*.html" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  | sort | xargs sha256sum 2>/dev/null | sha256sum | awk '{print $1}')

if [[ -f "$HASH_FILE" ]]; then
  PREV_HASH=$(cat "$HASH_FILE")
  if [[ "$CURRENT_HASH" == "$PREV_HASH" ]] && [[ "$DRY_RUN" == "false" ]]; then
    echo "[sync-backend] frontend unchanged — nothing to do"
    notify_nothing "sync-backend"
    exit 0
  fi
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] frontend changed — scanning for API calls..." | tee -a "$LOG_FILE"

# ---- Build prompt ------------------------------------------------------
read -r -d '' PROMPT << 'PROMPT_EOF'
You are maintaining the Go backend at gospel-experience/src/.

Stephen is building the frontend. Your job is to make sure the backend has every API endpoint his frontend code is calling.

## Step 1 — Scan the frontend for API calls

Find all frontend source files (JS/TS/JSX/TSX/Vue/Svelte) in gospel-experience/frontend/ (or web/, client/, app/ — whichever exists). Read them and extract every API call you find. Look for patterns like:
- fetch('/api/...')
- fetch(`/api/...`)
- axios.get('/api/...'), axios.post(...)
- api.get(...), api.post(...), api.put(...), api.delete(...)
- useQuery(..., '/api/...')
- Any HTTP call to a path starting with /api/

Build a list: METHOD /api/path for each unique call found.

## Step 2 — Check what the backend already has

Read gospel-experience/src/internal/router/router.go and list every registered route.

## Step 3 — Find the gaps

Compare the two lists. Identify any endpoint the frontend is calling that is NOT registered in router.go.

## Step 4 — Implement each missing endpoint end-to-end

For each missing endpoint, implement it following the exact patterns already in the codebase:
1. Add any new model fields needed → internal/models/
2. Add repository method → internal/repository/
3. Add service method if business logic is needed → internal/service/
4. Add handler method → internal/handler/
5. Register the route in internal/router/router.go
6. If a new DB column is needed → create migrations/NNN_add_field.sql

Follow the exact code style in the existing files (same respond/respondError helpers, $N parameterised queries, same error wrapping).

## Step 5 — Verify

Run: cd gospel-experience/src && go build ./...

Fix any compile errors before finishing.

## Step 6 — Report (IMPORTANT FORMAT)

Print your summary in EXACTLY this format so it can be parsed:
SYNC_RESULT_START
ALREADY_IMPLEMENTED: GET /api/foo, POST /api/bar
NEWLY_ADDED: POST /api/sermons, GET /api/members/:id
BUILD_STATUS: ok
SYNC_RESULT_END

If nothing was added, write NEWLY_ADDED: none
Only change files in gospel-experience/src/. Do not touch frontend files.
PROMPT_EOF

# ---- Execute -----------------------------------------------------------
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[sync-backend] DRY RUN"
  claude --print "$PROMPT

DRY RUN: describe what you WOULD add but do NOT write any files."
  exit 0
fi

# Notify Discord that sync is starting
# (skip notify_start here — watchers handle startup notifications)

SYNC_OUTPUT=$(claude --dangerously-skip-permissions --print "$PROMPT" 2>&1)
EXIT_CODE=$?

echo "$SYNC_OUTPUT" | tee -a "$LOG_FILE"

# ---- Parse Claude's structured output ----------------------------------
ADDED_ROUTES=""
BUILD_OK=true

if echo "$SYNC_OUTPUT" | grep -q "SYNC_RESULT_START"; then
  NEWLY_ADDED=$(echo "$SYNC_OUTPUT" \
    | sed -n 's/^NEWLY_ADDED: //p' \
    | tr -d '\r')
  BUILD_STATUS=$(echo "$SYNC_OUTPUT" \
    | sed -n 's/^BUILD_STATUS: //p' \
    | tr -d '\r')

  [[ "$NEWLY_ADDED" != "none" ]] && ADDED_ROUTES="$NEWLY_ADDED"
  [[ "$BUILD_STATUS" != "ok" ]] && BUILD_OK=false
fi

# ---- Notify Discord ----------------------------------------------------
if [[ $EXIT_CODE -ne 0 ]] || [[ "$BUILD_OK" == "false" ]]; then
  ERROR_SNIPPET=$(echo "$SYNC_OUTPUT" | tail -20)
  notify_failure "sync-backend" "$ERROR_SNIPPET"
else
  notify_success "sync-backend" "$ADDED_ROUTES"
  echo "$CURRENT_HASH" > "$HASH_FILE"
fi

echo "[$TIMESTAMP] sync complete" >> "$LOG_FILE"
