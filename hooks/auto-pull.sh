#!/bin/bash
# Auto-pull ~/.claude settings on session start.
# On conflict: save remote versions as *.remote for Claude to merge.

cd "$HOME/.claude" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0
git remote get-url origin &>/dev/null || exit 0

# Auto-commit local changes to tracked files only
if ! git diff --quiet 2>/dev/null; then
  git add -u 2>/dev/null
  git commit --quiet -m "[auto-pull] save local $(hostname -s) $(date +%Y-%m-%d\ %H:%M)" 2>/dev/null
fi

# Pull — git merges non-overlapping changes automatically
if git pull --rebase --quiet 2>/dev/null; then
  exit 0
fi

# Conflict — save remote versions for Claude to merge
git rebase --abort 2>/dev/null
git fetch --quiet origin 2>/dev/null

UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "origin/main")

HAS_CONFLICTS=false
for file in $(git diff --name-only HEAD "$UPSTREAM" 2>/dev/null); do
  git show "$UPSTREAM:$file" > "$HOME/.claude/$file.remote" 2>/dev/null
  HAS_CONFLICTS=true
done

if [ "$HAS_CONFLICTS" = true ]; then
  printf "=== SETTINGS CONFLICT ===\n"
  printf "Remote versions saved as *.remote. Merge them and run: csync\n"
fi
