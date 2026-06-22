# Claude Code Global Settings

Shared [Claude Code](https://claude.ai/claude-code) configuration synced across machines via git.

## What's synced

- `settings.json` -- hooks, permissions, enabled plugins, marketplace sources
- `CLAUDE.md` -- global instructions loaded every session
- `rules/` -- modular rule files (orchestration, QA, external sources, style, git workflow, ...)
- `hooks/` -- shell hooks for session automation and safety guards (private `rtk`/`mempal` hooks excluded)
- `agents/` -- custom agent definitions
- `agent-references/` -- agent-scoped reference docs read explicitly by specialist agents (Compose / Swift UI); file-scoped Kotlin rules live in `rules/`
- `skills/` -- custom skills (directories only, not symlinks)
- `scripts/` -- helper scripts (`gh` toolkit, ...)
- `setup.sh`, `statusline-command.sh`, `.pre-commit-config.yaml`, `.github/` -- bootstrap, status line, secret-scanning CI

## What stays local

`.credentials.json`, `credentials.md`, `channels/`, `settings.local.json`, `installed_plugins.json`, `mcp-needs-auth-cache.json`, `*.jsonl` (incl. `history.jsonl`), `projects/`, `swarm-report/`, project/session memory, caches, debug logs, `*.remote` conflict files, private `rtk`/`mempal` hooks.

## Setup

### New machine (no `~/.claude`)

```bash
git clone https://github.com/kirich1409/claude-global-settings.git ~/.claude
```

### Existing machine (already has `~/.claude`)

```bash
bash ~/.claude/setup.sh
# or if ~/.claude is not yet a repo:
git clone https://github.com/kirich1409/claude-global-settings.git /tmp/claude-settings \
  && bash /tmp/claude-settings/setup.sh \
  && rm -rf /tmp/claude-settings
```

The setup script creates a full backup before any changes, adds `csync` alias, and rolls back on failure.

## Sync

**Pull** is automatic -- `SessionStart` hook runs `git pull --rebase` at the beginning of every Claude Code session.

**Push** is manual -- run `csync` after changing settings, hooks, or skills.

On conflict, both scripts save remote versions as `*.remote` files. Claude auto-merges them at session start (see `CLAUDE.md`), or you can merge manually and run `csync`.

## Portability

- Use `$HOME/.claude/...` in paths, never `/Users/<username>/...`
- `.gitignore` uses a whitelist: everything ignored by default, only portable files allowed
