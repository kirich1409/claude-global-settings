#!/bin/bash
# Auto-pull ~/.claude settings on session start.
# Strategy: auto-commit local, pull preferring remote, auto-resolve conflicts.

cd "$HOME/.claude" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0
git remote get-url origin &>/dev/null || exit 0

# Auto-commit any uncommitted local changes (so nothing is lost)
git add -A 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit --quiet -m "pre-pull auto-save $(hostname -s) $(date +%Y-%m-%d\ %H:%M)" 2>/dev/null
fi

# Pull with auto-resolve: prefer remote on conflicts
# (rebase context: -X ours = prefer upstream = remote)
if ! git pull --rebase -X ours --quiet 2>/dev/null; then
  # Rebase failed — accept remote entirely, local commit stays in reflog
  git rebase --abort 2>/dev/null
  git reset --hard origin/main 2>/dev/null
  echo "~/.claude: synced from remote (local changes saved in git reflog)" >&2
fi
