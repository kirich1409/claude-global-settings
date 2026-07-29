# Claude Code Global Settings

Shared [Claude Code](https://claude.ai/claude-code) configuration synced across machines via git.

## What's synced

- `settings.json` -- hooks, permissions, enabled plugins, marketplace sources
- `CLAUDE.md` -- global instructions loaded every session
- `rules/` -- modular rule files (orchestration, QA, external sources, style, git workflow, ...)
- `hooks/` -- shell hooks for session automation and safety guards (private `rtk`/`mempal` hooks excluded)
- `agents/` -- custom agent definitions
- `skills/` -- custom skills (directories only, not symlinks)
- `scripts/` -- helper scripts (`gh` toolkit, ...)
- `setup.sh`, `statusline-command.sh`, `.pre-commit-config.yaml`, `.github/` -- bootstrap, status line, secret-scanning CI

## What stays local

`.credentials.json`, `credentials.md`, `channels/`, `settings.local.json`, `installed_plugins.json`, `mcp-needs-auth-cache.json`, `*.jsonl` (incl. `history.jsonl`), `projects/`, `swarm-report/`, project/session memory, caches, debug logs, `*.remote` conflict files, private `rtk`/`mempal` hooks.

Note that `skills/agents-best-practices` is a symlink to a local directory outside the repo -- it is not synced and will be absent on other machines. Private directories (`projects/`, `sessions/`, `agent-memory/`, etc.) are excluded by the whitelist `.gitignore`: everything is ignored by default, only explicitly allowed portable files are tracked.

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

Changes to tracked files go straight to `main`. Whether a repository requires a pull request is decided by its own branch protection and project instructions, not by this global harness.

**`csync`** (alias for `hooks/sync-settings.sh`) is the two-way sync: fetch, `add -A`, commit, rebase onto `origin/main`, push. A rebase conflict stops it loudly and changes nothing -- that is a real decision, not a sync detail.

**The `SessionStart` auto-pull hook** (`hooks/auto-pull.sh`) only pulls. It never commits or pushes; a dirty or ahead-of-origin `main` is ordinary working state, reported as information rather than an alarm.

**Pull requests are opt-in** for a change worth reviewing: `scripts/cgs-pr.sh new <slug>` creates the worktree + branch, `scripts/cgs-pr.sh ship "<title>"` commits, pushes, opens the PR, and enables auto-merge.

## Portability

- Use `$HOME/.claude/...` in paths, never `/Users/<username>/...`
- `.gitignore` uses a whitelist: everything ignored by default, only portable files allowed
