# Driftless

> AI-powered sync engine that keeps your frontend and backend in lockstep — automatically.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## The Problem

You're building full-stack. Your frontend dev adds a new API call. Your backend doesn't have that route yet. Nothing works. You context-switch, implement the endpoint, forget to add the migration, break the build.

**Stack drift is silent, constant, and expensive.**

---

## What Driftless Does

Driftless watches your frontend code for API calls, compares them against your backend, and uses your AI coding agent of choice to implement anything that's missing — automatically, in real time.

```
You save a frontend file
        ↓
Driftless detects the change
        ↓
Scans for API calls (fetch, axios, useQuery, etc.)
        ↓
Compares against your backend routes
        ↓
AI implements every missing endpoint
        ↓
Build verified ✅
        ↓
Discord notified 📣
```

No manual wiring. No context switching. No drift.

---

## Language Agnostic

Driftless doesn't care what stack you're on. The AI reads your codebase, learns its patterns, and writes code that fits — in whatever language and framework you're already using.

| Frontend | Backend | Status |
|----------|---------|--------|
| React / Next.js | Go (Fiber, Gin, Echo) | ✅ |
| Vue / Nuxt | Node.js (Express, Fastify, Hono) | ✅ |
| Svelte / SvelteKit | Python (FastAPI, Django, Flask) | ✅ |
| Angular | Ruby on Rails | ✅ |
| Vanilla JS/TS | Rust (Axum, Actix) | ✅ |
| Any | Any | ✅ |

---

## AI Backend Agnostic

Swap in whatever AI coding agent your team already uses. No lock-in.

| Agent | Config Value |
|-------|-------------|
| Claude Code | `claude` |
| OpenAI Codex | `codex` |
| Gemini CLI | `gemini` |
| Aider | `aider` |
| Custom | bring your own |

---

## Quick Start

### 1. Clone Driftless

```bash
git clone https://github.com/cardoza1991/Driftless.git
cd Driftless
chmod +x scripts/*.sh
```

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env`:

```bash
# AI backend (claude | codex | gemini | aider)
DRIFTLESS_AI=claude

# Discord webhook for notifications (optional but recommended)
STACKSYNC_WEBHOOK=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN

# Path to your project repo
DRIFTLESS_REPO=/path/to/your/project
```

### 3. Run

```bash
# Watch frontend files — triggers on every save
./scripts/watch-frontend.sh --daemon

# Watch an API contract file (optional)
./scripts/watch-contract.sh --daemon

# Or trigger a manual sync
./scripts/sync-backend.sh
```

That's it. Driftless is now running.

---

## How It Works

### Trigger Layer
`watch-frontend.sh` uses `inotifywait` to monitor your frontend source files (`.js`, `.ts`, `.jsx`, `.tsx`, `.vue`, `.svelte`). A 3-second debounce prevents firing on every keystroke.

`watch-contract.sh` watches an optional `api-contract/contract.yaml` for contract-first workflows. Either dev can update the contract — Driftless catches both.

### Sync Engine
`sync-backend.sh` is the core. It:
1. Hashes your frontend files — skips if nothing changed
2. Builds a prompt describing your codebase
3. Calls your AI agent with full repo context
4. Asks the AI to scan frontend API calls, compare against backend routes, and implement every gap end-to-end
5. Verifies the build passes
6. Parses structured output to report exactly what was added

### Notification Layer
`notify.sh` sends rich Discord embeds on every sync event — start, success, failure, no-op, and contract changes. Your whole team sees what the AI did in real time.

---

## Discord Notifications

Every sync event posts to your team Discord automatically.

| Event | Color | Trigger |
|-------|-------|---------|
| 🟢 Watcher started | Blue | Driftless boots up |
| 📄 Contract updated | Yellow | `contract.yaml` written |
| ✅ Sync complete | Green | AI synced successfully |
| ⏭️ No changes | Gray | Frontend unchanged |
| ❌ Sync failed | Red | Build error or AI failure |

See [DISCORD_SETUP.md](DISCORD_SETUP.md) for the full setup guide.

---

## Project Structure

```
Driftless/
├── scripts/
│   ├── notify.sh           # Discord notification layer
│   ├── sync-backend.sh     # Core sync engine
│   ├── watch-frontend.sh   # Frontend file watcher
│   └── watch-contract.sh   # API contract watcher
├── .env.example            # Config template
├── DISCORD_SETUP.md        # Discord server setup guide
├── CONTRIBUTING.md         # How to add AI adapters or language support
└── README.md
```

---

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `DRIFTLESS_AI` | `claude` | AI backend to use |
| `DRIFTLESS_REPO` | `../` | Path to your project |
| `STACKSYNC_WEBHOOK` | — | Discord webhook URL |
| `DRIFTLESS_DEBOUNCE` | `3` | Seconds to wait before triggering sync |
| `DRIFTLESS_FRONTEND` | auto | Frontend dir (auto-detects `frontend/`, `web/`, `client/`, `app/`) |

---

## Dry Run Mode

Not ready to let the AI write code yet? Run in dry-run mode — Driftless will tell you exactly what it *would* add without touching anything.

```bash
./scripts/sync-backend.sh --dry-run
```

---

## Adding a New AI Backend

Driftless uses a simple adapter pattern. To add a new AI agent, edit `scripts/sync-backend.sh`:

```bash
call_ai() {
  local prompt="$1"
  case "$DRIFTLESS_AI" in
    claude)  claude --dangerously-skip-permissions --print "$prompt" ;;
    codex)   codex --quiet "$prompt" ;;
    gemini)  gemini-cli --prompt "$prompt" ;;
    aider)   aider --message "$prompt" --yes ;;
    *)       echo "Unknown AI backend: $DRIFTLESS_AI"; exit 1 ;;
  esac
}
```

Add your case, open a PR — that's it.

---

## Roadmap

- [ ] GitHub App (webhook-triggered, no server needed)
- [ ] `driftless init` setup wizard
- [ ] Bidirectional sync (AI also generates typed frontend API clients)
- [ ] Auto-generated tests for each synced endpoint
- [ ] VS Code extension
- [ ] Windows support (WSL-based watcher)

---

## Contributing

PRs welcome — especially new AI adapters and language-specific prompt improvements.

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT © [Michael Cardoza](https://github.com/cardoza1991) — Cardoza Services LLC
