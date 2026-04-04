#!/bin/bash
# Manual sync: commit local changes, pull remote, push.
# Strategy: auto-resolve conflicts preferring local. Usage: csync

set -euo pipefail

cd "$HOME/.claude"
git rev-parse --git-dir &>/dev/null || { echo "Not a git repo: ~/.claude"; exit 1; }
git remote get-url origin &>/dev/null || { echo "No remote configured."; exit 1; }

# 1. Commit local changes
git add -A
if ! git diff --cached --quiet; then
  git commit --quiet -m "sync $(hostname -s) $(date +%Y-%m-%d\ %H:%M)"
  echo "Committed local changes."
else
  echo "No local changes."
fi

# 2. Pull remote, auto-resolve preferring local
# (rebase context: -X theirs = prefer commits being replayed = local)
if ! git pull --rebase -X theirs --quiet 2>/dev/null; then
  # Shouldn't happen with -X theirs, but just in case
  git rebase --abort 2>/dev/null
  echo "Could not auto-resolve. Run manually:"
  echo "  cd ~/.claude && git pull --rebase"
  exit 1
fi

# 3. Push
LOCAL_AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
if [ "$LOCAL_AHEAD" -gt 0 ]; then
  if git push --quiet; then
    echo "Pushed."
  else
    echo "Push failed. Retry: cd ~/.claude && git push"
    exit 1
  fi
else
  echo "Up to date."
fi
