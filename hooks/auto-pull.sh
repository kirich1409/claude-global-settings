#!/bin/bash
# Auto-pull ~/.claude settings on session start.
# Strategy: auto-commit local, pull --rebase (git merges non-overlapping changes).
# On real conflict: abort, keep local state, warn user to run csync manually.

cd "$HOME/.claude" || exit 0
git rev-parse --git-dir &>/dev/null || exit 0
git remote get-url origin &>/dev/null || exit 0

# Auto-commit any uncommitted local changes (so nothing is lost)
git add -A 2>/dev/null
if ! git diff --cached --quiet 2>/dev/null; then
  git commit --quiet -m "pre-pull auto-save $(hostname -s) $(date +%Y-%m-%d\ %H:%M)" 2>/dev/null
fi

# Pull — git auto-merges non-overlapping changes
if ! git pull --rebase --quiet 2>/dev/null; then
  # Real conflict — abort, keep local as-is, session starts normally
  git rebase --abort 2>/dev/null
  echo "~/.claude: remote has conflicting changes. Run 'csync' to resolve." >&2
fi
