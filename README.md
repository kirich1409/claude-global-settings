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

Tracked files are edited on `main` in the main checkout and delivered straight to `origin/main`. A pull request is an opt-in tool, not the default route.

**`csync`** (alias for `hooks/sync-settings.sh`) -- the two-way sync: `git add -A`, commit as `sync <host> <date>`, fetch, rebase onto `origin/main`, push. The `.gitignore` is a whitelist, so `add -A` only ever picks up config files. On a rebase conflict it aborts and saves the remote versions as `*.remote` for a manual merge.

**`SessionStart` auto-pull** (`hooks/auto-pull.sh`) -- pull only, fast-forward `main` to `origin/main`. It never commits or pushes; uncommitted edits and unpushed commits are reported (statusline + stdout) as a reminder to run `csync`, not as errors.

**Opt-in PR** -- `scripts/cgs-pr.sh new <slug>` creates a worktree + branch, `scripts/cgs-pr.sh ship "<title>"` commits, pushes, opens the PR, and enables auto-merge.

Because a direct commit reaches a public repo unreviewed, install the local secret gate once: `pip install pre-commit && pre-commit install` (gitleaks, see `.pre-commit-config.yaml`).

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

## Effort sweep

`effort` values must be measured per model, not carried over: the Opus 5 docs say to re-run a
sweep on real workloads rather than reusing settings from an earlier model. Pick three tasks
you actually repeat — one mechanical, one implementation, one review — and run each at three
levels, comparing cost against whether the result held up:

```bash
for e in low medium high; do
  printf '%s' "$TASK" | claude -p --model opus --output-format json \
    | jq -c "{effort:\"$e\"} + (.usage | {output_tokens, cache_creation_input_tokens}) + {cost:.total_cost_usd}"
done
```

Set the level per agent in its frontmatter `effort:`, not globally — the whole point is that a
mechanical worker and a root-cause debugger want different settings. Step down only where the
lower level held quality on your own tasks; the docs are explicit that `low` and `medium` are
usable far more widely on Opus 5 than on earlier models.

## Portability

- Use `$HOME/.claude/...` in paths, never `/Users/<username>/...`
- `.gitignore` uses a whitelist: everything ignored by default, only portable files allowed
