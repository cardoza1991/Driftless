# StackSync Discord Setup Guide

## 1. Create the Server

1. Open Discord → click **+** (Add a Server) → **Create My Own** → **For a club or community**
2. Name it: `StackSync` (or `gospel-experience dev`)
3. Skip the invite step for now

---

## 2. Create Channels

Recommended channel structure:

```
📁 STACKSYNC
   # sync-feed        ← all notifications land here
   # sync-errors      ← failures only (optional, for noise separation)
   # deploy-log       ← future use

📁 TEAM
   # general
   # dev-chat
```

---

## 3. Create the Webhook

1. Right-click **#sync-feed** → **Edit Channel**
2. Go to **Integrations** → **Webhooks** → **New Webhook**
3. Name it: `StackSync Bot`
4. (Optional) Upload a bot avatar — a gear icon or lightning bolt works well
5. Click **Copy Webhook URL**

It looks like:
```
https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz
```

---

## 4. Configure Your Environment

Add the webhook to your `.env` file in the repo root:

```bash
# gospel-experience/.env
STACKSYNC_WEBHOOK=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN
```

Or export it in your shell session:
```bash
export STACKSYNC_WEBHOOK="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
```

> ⚠️ Add `.env` to `.gitignore` — never commit the webhook URL.

```bash
echo ".env" >> .gitignore
```

---

## 5. Share with Stephen

1. In your StackSync Discord server → click **Invite People**
2. Generate an invite link and send it to Stephen
3. Give him the **#sync-feed** channel — he'll see every sync event in real time

---

## 6. Test It

Run a quick test before wiring into the full system:

```bash
source scripts/notify.sh
notify_start "test" "/my/repo/frontend"
notify_success "test" "POST /api/sermons, GET /api/members/:id"
notify_failure "test" "go build failed: undefined SermonHandler"
notify_nothing "test"
```

You should see 4 messages appear in **#sync-feed** immediately.

---

## 7. Start the Watchers

```bash
# Run both watchers as daemons
./scripts/watch-frontend.sh --daemon
./scripts/watch-contract.sh --daemon

# Confirm they're running
ps aux | grep watch

# Follow the log
tail -f scripts/sync.log
```

---

## Notification Reference

| Event | Color | When |
|-------|-------|------|
| 🟢 Watcher started | Blue | watch-frontend / watch-contract boots up |
| 📄 Contract updated | Yellow | contract.yaml is written |
| ✅ Sync complete | Green | Claude synced backend successfully |
| ⏭️ No changes | Gray | Hash check — frontend unchanged |
| ❌ Sync failed | Red | Build error or Claude failure |

---

## Optional: Errors-Only Channel

If `#sync-feed` gets noisy, create a `#sync-errors` channel with its own webhook and set:

```bash
# .env
STACKSYNC_WEBHOOK=https://discord.com/api/webhooks/.../...         # all events
STACKSYNC_ERROR_WEBHOOK=https://discord.com/api/webhooks/.../...   # errors only
```

Then in `notify.sh`, update `notify_failure()` to post to `$STACKSYNC_ERROR_WEBHOOK` as well.
