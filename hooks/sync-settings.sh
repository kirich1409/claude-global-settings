#!/bin/bash
# Manual sync: commit local changes, pull remote, push.
# Usage: csync

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
LOCK="/tmp/.claude-sync.lock"

# Prevent concurrent runs (macOS flock via perl fallback)
exec 9>"$LOCK"
if command -v flock &>/dev/null; then
  flock -n 9 || { echo "Another sync is running."; exit 1; }
else
  # macOS: try perl-based lock
  perl -e 'use Fcntl qw(:flock); open(F, ">&=9"); flock(F, LOCK_EX|LOCK_NB) or die' 2>/dev/null \
    || { echo "Another sync is running."; exit 1; }
fi

cd "$CLAUDE_DIR"
git rev-parse --git-dir &>/dev/null || { echo "Not a git repo: $CLAUDE_DIR"; exit 1; }
git remote get-url origin &>/dev/null || { echo "No remote configured."; exit 1; }

# 1. Commit local changes
git add -A
if ! git diff --cached --quiet; then
  git commit --quiet -m "auto-sync $(hostname -s) $(date +%Y-%m-%d\ %H:%M)"
  echo "Committed local changes."
fi

# 2. Pull remote (rebase to keep history linear)
if ! git pull --rebase --quiet; then
  echo ""
  echo "Conflict during pull. Resolve manually:"
  echo "  cd $CLAUDE_DIR"
  echo "  # fix conflicts, then:"
  echo "  git add <files>"
  echo "  git rebase --continue"
  echo "  git push"
  echo ""
  echo "  # or abort:"
  echo "  git rebase --abort"
  exit 1
fi

# 3. Push
if [ "$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)" -gt 0 ]; then
  if ! git push --quiet; then
    echo "Push failed. Try: cd $CLAUDE_DIR && git push"
    exit 1
  fi
  echo "Pushed."
else
  echo "Up to date."
fi
