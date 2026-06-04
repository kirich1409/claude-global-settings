#!/bin/bash
# Commit and push ~/.claude settings. Usage: csync

set -euo pipefail

LOCK="/tmp/.claude-sync.lock"
exec 9>"$LOCK"
perl -e 'use Fcntl qw(:flock); open(F, ">&=9"); flock(F, LOCK_EX|LOCK_NB) or die' 2>/dev/null \
  || { echo "Another csync is running."; exit 1; }

cd "$HOME/.claude"

# Clean up stale rebase state
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  git rebase --abort 2>/dev/null
fi

# Check upstream is configured
if ! git rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
  echo "No upstream configured. Run: git -C ~/.claude branch --set-upstream-to=origin/main"
  exit 1
fi

# Commit local changes
git add -A
if ! git diff --cached --quiet; then
  git commit --quiet -m "sync $(hostname -s) $(date +%Y-%m-%d\ %H:%M)"
  echo "Committed."
else
  echo "No local changes."
fi

# Pull remote — rebase replays local commits on top of remote.
# Fetch first so we can detect which files were edited on BOTH sides: those are
# silently union-merged (see .gitattributes) and may now contain duplicate lines.
git fetch --quiet origin 2>/dev/null || { echo "Fetch failed (network?)."; exit 1; }
UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "origin/main")
BASE=$(git merge-base HEAD "$UPSTREAM" 2>/dev/null)
UNION_MERGED=""
if [ -n "$BASE" ]; then
  both_sides=$(comm -12 \
    <(git diff --name-only "$BASE" HEAD 2>/dev/null | sort) \
    <(git diff --name-only "$BASE" "$UPSTREAM" 2>/dev/null | sort))
  for file in $both_sides; do
    if [ "$(git check-attr merge -- "$file" 2>/dev/null | sed 's/.*: //')" = "union" ]; then
      UNION_MERGED="$UNION_MERGED $file"
    fi
  done
fi

if ! git rebase --quiet "$UPSTREAM"; then
  # Real conflict — abort rebase, save .remote files like auto-pull does
  git rebase --abort 2>/dev/null
  for file in $(git diff --name-only HEAD "$UPSTREAM" 2>/dev/null); do
    git show "$UPSTREAM:$file" > "$HOME/.claude/$file.remote" 2>/dev/null
  done
  echo "Conflict. Remote versions saved as *.remote."
  echo "Merge them with your local files, delete .remote, then run csync again."
  exit 1
fi

if [ -n "$UNION_MERGED" ]; then
  echo "⚠ Auto-merged concurrent edits (union) — check for duplicate lines:"
  for file in $UNION_MERGED; do echo "   $file"; done
fi

# Push
if [ "$(git rev-list --count '@{u}..HEAD')" -gt 0 ]; then
  git push --quiet && echo "Pushed." || { echo "Push failed."; exit 1; }
else
  echo "Up to date."
fi
