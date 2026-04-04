#!/bin/bash
# Auto-sync ~/.claude git repo: pull remote changes, commit local changes, push.
# Designed to run silently from cron/launchd.

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
LOCK="/tmp/.claude-sync.lock"

# Prevent concurrent runs
exec 9>"$LOCK"
flock -n 9 || exit 0

cd "$CLAUDE_DIR"

# Must be a git repo with a remote
git rev-parse --git-dir &>/dev/null || exit 0
git remote get-url origin &>/dev/null || exit 0

# Pull remote changes (rebase to keep history clean)
git pull --rebase --quiet 2>/dev/null || true

# Stage tracked + new whitelisted files
git add -A

# Commit only if there are changes
if ! git diff --cached --quiet; then
  git commit --quiet -m "auto-sync $(hostname -s) $(date +%Y-%m-%d\ %H:%M)"
fi

# Push if ahead of remote
if [ "$(git rev-list --count @{u}..HEAD 2>/dev/null)" -gt 0 ]; then
  git push --quiet 2>/dev/null || true
fi
