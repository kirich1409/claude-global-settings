#!/bin/bash
# Auto-pull ~/.claude settings on session start.
# On conflict: save remote versions as *.remote for Claude to merge.
# Must never break a Claude Code session — all failures exit 0.

cd "$HOME/.claude" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0
git remote get-url origin &>/dev/null || exit 0

# Clean up stale rebase state from a previous crash
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  git rebase --abort 2>/dev/null
fi

# Auto-commit local changes to tracked files (so pull doesn't overwrite them)
if ! git diff --quiet 2>/dev/null; then
  if ! git add -u 2>/dev/null || ! git commit --quiet -m "[auto-pull] save local $(hostname -s)" 2>/dev/null; then
    # Can't commit — skip pull to protect local changes
    exit 0
  fi
fi

# Pull — rebase replays local commits on top of remote
if git pull --rebase --quiet 2>/dev/null; then
  exit 0
fi

# Conflict — abort rebase, save remote versions for Claude to merge
if ! git rebase --abort 2>/dev/null; then
  printf "~/.claude: rebase abort failed. Run: cd ~/.claude && git rebase --abort\n" >&2
  exit 0
fi

if ! git fetch --quiet origin 2>/dev/null; then
  printf "~/.claude: fetch failed (network?). Settings may be out of sync.\n" >&2
  exit 0
fi

UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "origin/main")
HAS_CONFLICTS=false
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if git show "$UPSTREAM:$file" > "$HOME/.claude/$file.remote" 2>/dev/null; then
    HAS_CONFLICTS=true
  fi
done < <(git diff --name-only HEAD "$UPSTREAM" 2>/dev/null)

if [ "$HAS_CONFLICTS" = true ]; then
  printf "=== SETTINGS CONFLICT ===\n"
  printf "Remote versions saved as *.remote. Merge them and run: csync\n"
fi
