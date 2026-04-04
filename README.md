# Claude Code Global Settings

Shared [Claude Code](https://claude.ai/claude-code) configuration synced across machines via git.

## What's synced

- `settings.json` -- hooks, permissions, enabled plugins, language, effort level
- `CLAUDE.md`, `RTK.md` -- global instructions loaded every session
- `hooks/` -- shell hooks (RTK rewrite, branch guard, auto-pull, sync)
- `agents/`, `agent-memory/` -- custom agent definitions and their memory
- `skills/` -- universal custom skills (not project-specific, not symlinks)
- `plugins/blocklist.json`, `plugins/known_marketplaces.json` -- marketplace sources

## What stays local

Credentials, `settings.local.json`, `installed_plugins.json`, project memory, sessions, caches, debug logs.

## Setup

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kirich1409/claude-global-settings/main/setup.sh)
```

Works on any machine: clones if `~/.claude` doesn't exist, overlays shared settings if it does, pulls if already set up. Backs up local files automatically, adds `csync` alias.

## Sync

**Pull** is automatic -- `SessionStart` hook runs `git pull --rebase` at the beginning of every Claude Code session.

**Push** is manual -- run `csync` after changing settings, hooks, or skills.

On conflict, Claude auto-resolves at session start by merging `*.remote` files. See `CLAUDE.md` for details.

## Portability

- Use `$HOME/.claude/...` in paths, never `/Users/<username>/...`
- `.gitignore` uses a whitelist: everything ignored by default, only portable files allowed
