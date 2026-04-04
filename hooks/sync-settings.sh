#!/bin/bash
# Commit and push ~/.claude settings. Usage: csync

set -euo pipefail

LOCK="/tmp/.claude-sync.lock"
exec 9>"$LOCK"
perl -e 'use Fcntl qw(:flock); open(F, ">&=9"); flock(F, LOCK_EX|LOCK_NB) or die' 2>/dev/null \
  || { echo "Another csync is running."; exit 1; }

cd "$HOME/.claude"

# Commit local changes
git add -A
if ! git diff --cached --quiet; then
  git commit --quiet -m "sync $(hostname -s) $(date +%Y-%m-%d\ %H:%M)"
  echo "Committed."
fi

# Pull remote (git merges non-overlapping changes)
if ! git pull --rebase --quiet; then
  echo "Conflict. Resolve in ~/.claude, then run csync again."
  exit 1
fi

# Push
if [ "$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)" -gt 0 ]; then
  git push --quiet && echo "Pushed." || { echo "Push failed."; exit 1; }
else
  echo "Up to date."
fi
