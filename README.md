# Claude Code Global Settings

Shared [Claude Code](https://claude.ai/claude-code) configuration synced across machines via git.

## What's synced

- `settings.json` -- hooks, permissions, enabled plugins, marketplace sources
- `CLAUDE.md` -- global instructions loaded every session
- `rules/` -- modular rule files; those without frontmatter load every session, those with `paths:` load only when a matching file is read
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

PR-only: `main` always stays clean, and every change to a tracked file ships through a branch + pull request with auto-merge -- never a direct commit to `main`.

**Pull** -- `csync` (alias for `hooks/sync-settings.sh`) and the `SessionStart` auto-pull hook (`hooks/auto-pull.sh`) only fetch and fast-forward `main` to `origin/main`. Neither ever commits, pushes, or opens a PR. A dirty or ahead-of-origin `main` is a loud error (statusline + OS notification), not something they auto-fix.

**Push** -- edit tracked files (`CLAUDE.md`, `rules/`, `settings*.json`, `hooks/`, `scripts/`, `skills/`, `agents/`) on a branch, preferably via a worktree, then open a PR: `scripts/cgs-pr.sh new <slug>` creates the worktree + branch, `scripts/cgs-pr.sh ship "<title>"` commits, pushes, opens the PR, and enables auto-merge.

## Context budget

Everything in `CLAUDE.md`, unconditional `rules/`, and agent/skill frontmatter is loaded at
the start of every session — and again in every subagent, whose own base context is only
~4.6k tokens, so the same payload weighs far more there. Four tiers, cheapest first:

| Tier | Mechanism | Loads when | Main session | Subagent |
|---|---|---|---|---|
| 1 | `rules/*.md` without frontmatter | always | full cost | full cost, inherited |
| 2 | `rules/*.md` with `paths:` | a matching file is read | 0 | 0 until read |
| 3 | skill | Claude judges it relevant | ~190 t of description | 0 |
| 4 | agent `skills:` preload | that agent starts | 0 | full, only there |

Put a rule in tier 1 only if every session needs it. Anything keyed to a file type belongs in
tier 2; anything keyed to a kind of task belongs in tier 3. Tier 4 exists because 17 of 23
agents omit `Skill` from `tools` and cannot load a skill themselves.

Measure before and after changing this layer, rather than estimating:

```bash
# baseline in an empty directory, then the same with the layer pasted in as the prompt
printf 'Reply with exactly: ok' | claude -p --model haiku --output-format json | jq '.usage'
cat CLAUDE.md rules/<unconditional>.md > /tmp/layer.txt
{ cat /tmp/layer.txt; printf '\n\nok'; } | claude -p --model haiku --output-format json | jq '.usage'
```

Sum `input_tokens`, `cache_creation_input_tokens`, and `cache_read_input_tokens`; the
difference between the two runs is what the layer costs. `/context` in a live session shows
what actually loaded. For a per-file breakdown while debugging path-scoped or lazily loaded
rules, register an [`InstructionsLoaded`](https://code.claude.com/docs/en/hooks) hook
temporarily — it reports each file's path and load reason as it loads.

## Portability

- Use `$HOME/.claude/...` in paths, never `/Users/<username>/...`
- `.gitignore` uses a whitelist: everything ignored by default, only portable files allowed
