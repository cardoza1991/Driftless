#!/usr/bin/env bash
# notify.sh
# Sends rich Discord notifications for StackSync events.
# Source this file from sync-backend.sh and watch-*.sh scripts.
#
# Usage (after sourcing):
#   notify_start "watch-frontend" "/repo/frontend"
#   notify_success "watch-frontend" "POST /api/sermons, GET /api/members/:id"
#   notify_failure "sync-backend" "go build failed — undefined: SermonHandler"
#   notify_nothing "sync-backend"
#
# Config:
#   Set STACKSYNC_WEBHOOK in your environment or .env file:
#   export STACKSYNC_WEBHOOK="https://discord.com/api/webhooks/..."

# ---- Load .env if present ----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# ---- Validate webhook --------------------------------------------------
_check_webhook() {
  if [[ -z "${STACKSYNC_WEBHOOK:-}" ]]; then
    echo "[notify] WARNING: STACKSYNC_WEBHOOK not set — Discord notifications disabled"
    return 1
  fi
  return 0
}

# ---- Core sender -------------------------------------------------------
# _send_embed COLOR TITLE DESCRIPTION [FIELDS_JSON]
_send_embed() {
  local color="$1"    # decimal color int
  local title="$2"
  local description="$3"
  local fields="${4:-[]}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local payload
  payload=$(cat <<EOF
{
  "username": "StackSync",
  "avatar_url": "https://cdn.discordapp.com/embed/avatars/0.png",
  "embeds": [{
    "title": "$title",
    "description": "$description",
    "color": $color,
    "fields": $fields,
    "footer": {
      "text": "StackSync • $(hostname)"
    },
    "timestamp": "$timestamp"
  }]
}
EOF
)

  curl -s -X POST "$STACKSYNC_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null
}

# ---- Public API --------------------------------------------------------

# notify_start COMPONENT PATH
# Called when a watcher starts up
notify_start() {
  _check_webhook || return 0
  local component="${1:-StackSync}"
  local path="${2:-}"
  local desc="Watcher is online and listening for changes."
  [[ -n "$path" ]] && desc="$desc\n\`$path\`"

  _send_embed 3447003 "🟢 $component started" "$desc" "[]"
  # 3447003 = #3498db (blue)
}

# notify_success COMPONENT ADDED_ROUTES
# Called after a successful sync
notify_success() {
  _check_webhook || return 0
  local component="${1:-sync-backend}"
  local added="${2:-}"

  local fields="[]"
  if [[ -n "$added" ]]; then
    # Build a fields array listing each added route
    local routes_list=""
    IFS=',' read -ra ROUTES <<< "$added"
    for route in "${ROUTES[@]}"; do
      route="$(echo "$route" | xargs)"  # trim whitespace
      routes_list="${routes_list}\`${route}\`\n"
    done

    fields=$(cat <<EOF
[{
  "name": "Endpoints added",
  "value": "$routes_list",
  "inline": false
}]
EOF
)
  fi

  local desc="Backend is in sync with the frontend contract."
  [[ -z "$added" ]] && desc="All endpoints already implemented — nothing to add."

  _send_embed 3066993 "✅ Sync complete" "$desc" "$fields"
  # 3066993 = #2ecc71 (green)
}

# notify_failure COMPONENT ERROR_MSG
# Called when sync or build fails
notify_failure() {
  _check_webhook || return 0
  local component="${1:-sync-backend}"
  local error="${2:-unknown error}"

  # Truncate long errors
  if [[ ${#error} -gt 800 ]]; then
    error="${error:0:800}…"
  fi

  local fields
  fields=$(cat <<EOF
[{
  "name": "Error",
  "value": "\`\`\`\n$error\n\`\`\`",
  "inline": false
},{
  "name": "Next step",
  "value": "Check \`scripts/sync.log\` for the full trace.",
  "inline": false
}]
EOF
)

  _send_embed 15158332 "❌ Sync failed — $component" "A build or sync error needs attention." "$fields"
  # 15158332 = #e74c3c (red)
}

# notify_nothing COMPONENT
# Called when hash check shows no changes
notify_nothing() {
  _check_webhook || return 0
  local component="${1:-sync-backend}"
  _send_embed 9807270 "⏭️ No changes detected" "Frontend unchanged — skipping sync." "[]"
  # 9807270 = #959595 (gray)
}

# notify_contract_change AUTHOR
# Called when contract.yaml is written
notify_contract_change() {
  _check_webhook || return 0
  local author="${1:-unknown}"
  _send_embed 16776960 "📄 Contract updated" "\`api-contract/contract.yaml\` was modified — triggering sync." \
    "[{\"name\": \"Detected from\", \"value\": \"$author\", \"inline\": true}]"
  # 16776960 = #ffff00 (yellow)
}
