#!/bin/bash
# Manual sync: commit, pull, push. On conflict — show files and one-liner to finish.
# Usage: csync

set -euo pipefail

cd "$HOME/.claude"
git rev-parse --git-dir &>/dev/null || { echo "Not a git repo: ~/.claude"; exit 1; }
git remote get-url origin &>/dev/null || { echo "No remote configured."; exit 1; }

# 1. Commit local changes
git add -A
if ! git diff --cached --quiet; then
  git commit --quiet -m "sync $(hostname -s) $(date +%Y-%m-%d\ %H:%M)"
  echo "Committed local changes."
fi

# 2. Pull remote — git auto-merges non-overlapping changes
if ! git pull --rebase --quiet; then
  echo ""
  echo "Conflict in:"
  git diff --name-only --diff-filter=U 2>/dev/null | sed 's/^/  /'
  echo ""
  echo "Edit the files above, then run:"
  echo "  cd ~/.claude && git add -A && git rebase --continue && git push"
  echo ""
  echo "Or keep only your local version:"
  echo "  cd ~/.claude && git checkout --theirs . && git add -A && git rebase --continue && git push"
  echo ""
  echo "Or keep only remote version:"
  echo "  cd ~/.claude && git checkout --ours . && git add -A && git rebase --continue && git push"
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
