# Contributing to Driftless

Thanks for helping keep stacks driftless. Here's how to contribute.

---

## Adding an AI Backend Adapter

The easiest and most impactful contribution. If you use a coding agent that isn't supported yet, add it in 5 minutes.

1. Open `scripts/sync-backend.sh`
2. Find the `call_ai()` function
3. Add your case:

```bash
your_agent) your-agent-cli --flag "$prompt" ;;
```

4. Update the adapter table in `README.md`
5. Open a PR with the title: `feat: add [agent name] adapter`

---

## Improving Language-Specific Prompts

The sync prompt in `sync-backend.sh` is intentionally generic so the AI figures out the stack itself. But if you have prompt improvements that make syncing more reliable for a specific language or framework, open a PR with before/after examples.

---

## Reporting Bugs

Open an issue with:
- Your OS
- Your AI backend (`DRIFTLESS_AI` value)
- Your frontend/backend stack
- The contents of `scripts/sync.log` around the failure

---

## Code Style

- Bash only for the core scripts — keep it portable
- No external dependencies beyond `inotify-tools` and your AI agent CLI
- Every new feature gets a `--dry-run` compatible path

---

## Roadmap Items

If you want to tackle something on the roadmap, open an issue first so we can coordinate.
