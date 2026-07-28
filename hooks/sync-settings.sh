#!/bin/bash
# csync — synchronize ~/.claude with origin. Usage: csync
#
# Two-way sync: commit whatever changed locally, rebase on origin/main, push. Delivery of
# ~/.claude config goes straight to main; a PR is opened only when explicitly asked for
# (scripts/cgs-pr.sh). Nothing here forces a review model — that is the repository's job.
#
# Never fails silently: every non-OK outcome is reported and exits non-zero.

set -euo pipefail

LOCK="/tmp/.claude-sync.lock"
exec 9>"$LOCK"
perl -e 'use Fcntl qw(:flock); open(F, ">&=9"); flock(F, LOCK_EX|LOCK_NB) or die' 2>/dev/null \
  || { echo "Another csync is running."; exit 1; }

cd "$HOME/.claude"

# Clean up stale rebase state from a previous crash
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  git rebase --abort 2>/dev/null || true
fi

# csync only ever syncs the main checkout's main branch — a feature branch is someone's
# work in progress, not the config mirror.
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
if [ "$BRANCH" != "main" ]; then
  echo "⚠ Not on main (on '$BRANCH'). csync only syncs main; switch to main first."
  exit 1
fi

if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "No upstream configured. Run: git -C ~/.claude branch --set-upstream-to=origin/main"
  exit 1
fi

# Commit local changes. The .gitignore is a whitelist, so `add -A` only ever picks up
# tracked config paths — never memory, sessions or scratch state.
git add -A
if ! git diff --cached --quiet; then
  git commit --quiet -m "sync $(hostname -s) $(date +%Y-%m-%d\ %H:%M)"
  echo "Committed."
else
  echo "No local changes."
fi

# Fetch first so we can detect files edited on BOTH sides: those are silently union-merged
# (see .gitattributes) and may end up with duplicate lines.
git fetch --quiet origin || { echo "Fetch failed (network?)."; exit 1; }
UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "origin/main")
BASE=$(git merge-base HEAD "$UPSTREAM" 2>/dev/null || true)
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

# Rebase replays local commits on top of origin/main.
if ! git rebase --quiet "$UPSTREAM"; then
  git rebase --abort 2>/dev/null || true
  for file in $(git diff --name-only HEAD "$UPSTREAM" 2>/dev/null); do
    git show "$UPSTREAM:$file" > "$HOME/.claude/$file.remote" 2>/dev/null || true
  done
  echo "Conflict. Remote versions saved as *.remote."
  echo "Merge them with your local files, delete .remote, then run csync again."
  exit 1
fi

if [ -n "$UNION_MERGED" ]; then
  echo "⚠ Auto-merged concurrent edits (union) — check for duplicate lines:"
  for file in $UNION_MERGED; do echo "   $file"; done
fi

if [ "$(git rev-list --count '@{u}..HEAD')" -gt 0 ]; then
  git push --quiet && echo "Pushed." || { echo "Push failed."; exit 1; }
else
  echo "Up to date."
fi
