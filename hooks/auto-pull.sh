#!/bin/bash
# Auto-pull ~/.claude settings on session start.
# On conflict: save remote versions as *.remote for Claude to merge.

cd "$HOME/.claude" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0
git remote get-url origin &>/dev/null || exit 0

# Auto-commit local changes so nothing is lost
git add -A 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit --quiet -m "auto-save $(hostname -s) $(date +%Y-%m-%d\ %H:%M)" 2>/dev/null
fi

# Pull — git merges non-overlapping changes automatically
if git pull --rebase --quiet 2>/dev/null; then
  exit 0
fi

# Conflict — save remote versions for Claude to merge
git rebase --abort 2>/dev/null
git fetch --quiet origin 2>/dev/null

CONFLICTS=""
for file in $(git diff --name-only HEAD origin/main 2>/dev/null); do
  git show "origin/main:$file" > "$HOME/.claude/$file.remote" 2>/dev/null
  CONFLICTS="$CONFLICTS  $file\n"
done

if [ -n "$CONFLICTS" ]; then
  printf "=== SETTINGS CONFLICT ===\n"
  printf "Remote versions saved as *.remote:\n%b" "$CONFLICTS"
  printf "Merge them and run: csync\n"
fi
