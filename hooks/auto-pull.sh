#!/bin/bash
# Auto-pull ~/.claude settings on session start.
# Handles conflicts gracefully: stash local changes, pull, restore.

cd "$HOME/.claude" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0

# Stash local changes to tracked files (if any)
STASHED=false
if ! git diff --quiet 2>/dev/null; then
  git stash --quiet && STASHED=true
fi

# Pull remote
if ! git pull --rebase --quiet 2>/dev/null; then
  git rebase --abort 2>/dev/null
  [ "$STASHED" = true ] && git stash pop --quiet 2>/dev/null
  echo "⚠ ~/.claude: conflict pulling remote changes. Run: cd ~/.claude && git pull --rebase" >&2
  exit 0
fi

# Restore local changes
if [ "$STASHED" = true ]; then
  if ! git stash pop --quiet 2>/dev/null; then
    echo "⚠ ~/.claude: conflict restoring local changes. Run: cd ~/.claude && git stash pop" >&2
    exit 0
  fi
fi
