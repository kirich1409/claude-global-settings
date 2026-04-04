#!/bin/bash
# Auto-pull ~/.claude settings on session start.
# On conflict: save remote versions as *.remote, let Claude resolve.

cd "$HOME/.claude" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0
git remote get-url origin &>/dev/null || exit 0

# Auto-commit any uncommitted local changes
git add -A 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit --quiet -m "pre-pull auto-save $(hostname -s) $(date +%Y-%m-%d\ %H:%M)" 2>/dev/null
fi

# Try normal pull — git merges non-overlapping changes automatically
if git pull --rebase --quiet 2>/dev/null; then
  exit 0
fi

# Conflict — abort rebase, save remote versions for Claude to merge
git rebase --abort 2>/dev/null
git fetch --quiet origin 2>/dev/null

CONFLICTS=""
for file in $(git diff --name-only HEAD origin/main 2>/dev/null); do
  git show "origin/main:$file" > "$HOME/.claude/$file.remote" 2>/dev/null
  CONFLICTS="$CONFLICTS  $file\n"
done

if [ -n "$CONFLICTS" ]; then
  echo "=== SETTINGS CONFLICT ==="
  echo "Remote has different versions of these files:"
  echo -e "$CONFLICTS"
  echo "Remote versions saved as <file>.remote next to each file."
  echo "Please review and merge, then delete .remote files and run: csync"
fi
