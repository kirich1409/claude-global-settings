# Claude Code Global Settings

Shared [Claude Code](https://claude.ai/claude-code) configuration synced across machines via git.

## What's synced

| Category | Path | Description |
|----------|------|-------------|
| Settings | `settings.json` | Hooks, permissions, enabled plugins, language, effort level |
| Instructions | `CLAUDE.md`, `RTK.md` | Global instructions loaded every session |
| Hooks | `hooks/` | Shell hooks (RTK rewrite, branch guard, auto-pull, sync, etc.) |
| Agents | `agents/` | Custom agent definitions |
| Agent memory | `agent-memory/` | Persistent agent learning |
| Skills | `skills/` | Universal custom skills (not project-specific) |
| Plugin config | `plugins/blocklist.json`, `plugins/known_marketplaces.json` | Marketplace sources and blocklist |

## What's NOT synced (stays local)

- **Credentials** -- `.credentials.json`, `channels/telegram/.env`
- **Machine-specific** -- `settings.local.json`, `installed_plugins.json`
- **Project memory** -- `projects/*/memory/` (belongs in each project's repo)
- **Sessions & caches** -- `debug/`, `telemetry/`, `cache/`, `sessions/`, `*.jsonl`
- **Project-specific skills** -- e.g. `databinding-to-viewbinding-workspace/`
- **Symlinked skills** -- recreated by plugins on each machine

## Setup

### New machine (no `~/.claude` yet)

```bash
git clone git@github.com:kirich1409/claude-global-settings.git ~/.claude
```

Claude Code will create all missing local files (`settings.local.json`, `installed_plugins.json`, etc.) on first run.

### Existing machine (already has `~/.claude`)

```bash
cd ~/.claude

# Init repo and pull shared settings
git init
git remote add origin git@github.com:kirich1409/claude-global-settings.git
git fetch origin

# Backup local settings.json before overwriting
cp settings.json settings.json.local-backup

# Apply shared settings over local files
git reset --hard origin/main
git branch -M main
git branch --set-upstream-to=origin/main main

# Restore local-only files from backup if needed
# (only if they were overwritten or lost)
cp settings.json.local-backup settings.json.bak  # keep as reference
```

Review `settings.json` after setup -- merge any machine-specific permissions or plugins from `settings.json.local-backup` into `settings.local.json`.

## Sync

### Auto-pull (automatic)

A `SessionStart` hook runs `git pull --rebase` at the beginning of every Claude Code session. No action needed -- changes from other machines are pulled automatically.

### Push changes (manual)

After modifying settings, hooks, skills, or instructions, push with:

```bash
csync
```

This alias (add to your `.zshrc`) runs `~/.claude/hooks/sync-settings.sh` -- commits all tracked changes and pushes to remote.

```bash
# Add to .zshrc:
alias csync='$HOME/.claude/hooks/sync-settings.sh'
```

## Portability rules

- Use `$HOME/.claude/...` in paths, never `/Users/<username>/...`
- `.gitignore` uses a whitelist approach: everything is ignored by default, only portable files are explicitly allowed
- Project-specific skills go to `.gitignore`, not to the repo
