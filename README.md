# Claude Code Global Settings

Shared [Claude Code](https://claude.ai/claude-code) configuration synced across machines via git:
`CLAUDE.md`, `rules/`, `references/`, `agents/`, `skills/`, `hooks/`, `scripts/`, `settings.json`.
Everything else -- credentials, `settings.local.json`, session and project data, caches -- stays
local: `.gitignore` is a whitelist, so only portable files are tracked.

## Setup

New machine, no `~/.claude` yet:

```bash
git clone https://github.com/kirich1409/claude-global-settings.git ~/.claude
```

Existing `~/.claude`:

```bash
git clone https://github.com/kirich1409/claude-global-settings.git /tmp/claude-settings \
  && bash /tmp/claude-settings/setup.sh \
  && rm -rf /tmp/claude-settings
```

`setup.sh` backs up the current directory, adds the `csync` alias, and rolls back on failure.

## Sync

Changes go straight to `main`. **`csync`** (`hooks/sync-settings.sh`) is the two-way sync: fetch,
`add -A`, commit, rebase onto `origin/main`, push; a rebase conflict stops it and changes nothing.
The `SessionStart` hook (`hooks/auto-pull.sh`) only pulls, never commits or pushes.

## Editing rules

`CLAUDE.md` and every `rules/*.md` without `paths:` frontmatter are injected into every session and
every subagent before the first message -- `rules/` is walked recursively. Keep them to the
imperative core: what must happen, and when.

`references/` is never loaded automatically. Detail needed only at one specific moment lives there;
a rule points at `~/.claude/references/<name>.md`, and a subagent needs that path passed explicitly.
