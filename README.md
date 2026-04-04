# Claude Code Global Settings

Shared [Claude Code](https://claude.ai/claude-code) configuration synced across machines via git.

## What's synced

| Category | Path | Description |
|----------|------|-------------|
| Settings | `settings.json` | Hooks, permissions, enabled plugins, language, effort level |
| Instructions | `CLAUDE.md`, `RTK.md` | Global instructions loaded every session |
| Hooks | `hooks/` | Shell hooks (RTK rewrite, branch guard, cross-repo guard, etc.) |
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

## Setup on a new machine

```bash
# Back up existing config
mv ~/.claude ~/.claude.bak

# Clone
git clone git@github.com:kirich1409/claude-global-settings.git ~/.claude

# Restore local-only files
cp ~/.claude.bak/.credentials.json ~/.claude/ 2>/dev/null
cp -r ~/.claude.bak/channels/ ~/.claude/ 2>/dev/null
cp ~/.claude.bak/settings.local.json ~/.claude/ 2>/dev/null
```

## Portability rules

- Use `$HOME/.claude/...` in paths, never `/Users/<username>/...`
- `.gitignore` uses a whitelist approach: everything is ignored by default, only portable files are explicitly allowed
