#!/bin/bash
# Commit and push ~/.claude settings. Usage: csync

set -euo pipefail
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
