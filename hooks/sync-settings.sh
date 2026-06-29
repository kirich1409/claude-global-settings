#!/bin/bash
# csync — synchronize ~/.claude from origin/main. PULL-ONLY. Usage: csync
#
# Model: local main is a pure mirror of origin/main and must stay clean. This script ONLY
# fast-forwards local main to origin/main. It never commits, never pushes, never opens PRs.
#
# Making changes is the changer's responsibility, not the sync tool's: edit on a separate
# branch / worktree and merge via a pull request (auto-merge). A dirty or diverged main is a
# loud error here — never silently "fixed" by a commit.

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

# csync only ever syncs the main checkout's main branch.
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
if [ "$BRANCH" != "main" ]; then
  echo "⚠ Not on main (on '$BRANCH'). csync only syncs main; switch to main first."
  exit 1
fi

# Fetch — network failure is loud, not silent.
git fetch --quiet origin || { echo "Fetch failed (network?)."; exit 1; }

# Guard: tracked working-tree changes mean main was edited directly — move them to a branch+PR.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠ main has uncommitted tracked changes — main must stay clean."
  echo "  Move them to a branch + PR (auto-merge). csync does not commit or push."
  exit 1
fi

# Guard: local commits ahead of origin bypass the PR flow.
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
if [ "$AHEAD" -gt 0 ]; then
  echo "⚠ main is $AHEAD commit(s) ahead of origin — these bypass the PR flow."
  echo "  Reset main (git reset --hard origin/main) or move the commits to a branch + PR."
  exit 1
fi

# Fast-forward to origin/main.
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
if [ "$BEHIND" -gt 0 ]; then
  git merge --ff-only --quiet origin/main && echo "Pulled $BEHIND." || { echo "Fast-forward failed."; exit 1; }
else
  echo "Up to date."
fi
