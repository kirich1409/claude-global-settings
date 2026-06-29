#!/bin/bash
# Auto-sync ~/.claude on session start: fast-forward local main from origin. PULL-ONLY.
#
# Model: local main is a pure mirror of origin/main and must stay clean. This hook ONLY
# fast-forwards main; it never commits, never pushes, never opens PRs. Changes are the
# changer's responsibility — made on a branch / worktree and merged via a pull request
# (auto-merge), never on main.
#
# Core invariant: NEVER fail silently. Every non-OK outcome is recorded loudly via three
# channels — ~/.claude/.sync-status (rendered in the statusline on every prompt), an OS
# notification on hard failures, and stdout (which Claude relays). The hook always exits 0
# so it can never break a Claude Code session, but it never stays silent about a problem.
# A dirty or diverged main is a loud alarm here, never an automatic commit.

set -uo pipefail

REPO="$HOME/.claude"
STATUS="$REPO/.sync-status"

cd "$REPO" 2>/dev/null || exit 0

# Recursion guard: any `claude -p` spawned within sync must not re-enter (its own SessionStart
# would trigger this hook again). csync exports CLAUDE_SYNC_ACTIVE=1.
[ -n "${CLAUDE_SYNC_ACTIVE:-}" ] && exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

# --- loud channel helpers ---
note()  { printf '[claude-sync] %s\n' "$*"; }           # info -> stdout (Claude relays)
warn()  { printf '%s' "$*" > "$STATUS"; printf '⚠ ~/.claude: %s\n' "$*"; }  # soft -> statusline + stdout
alarm() {                                                # hard -> statusline + OS notif + stdout
  printf '%s' "$*" > "$STATUS"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$*\" with title \"~/.claude sync\"" >/dev/null 2>&1 || true
  fi
  printf '⚠ ~/.claude: %s\n' "$*"
}
clear_status() { rm -f "$STATUS" 2>/dev/null || true; } # OK -> clear warning

# Clean up stale rebase state from a previous crash
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  git rebase --abort 2>/dev/null || true
fi

# Only ever sync the main checkout's main branch.
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
if [ "$BRANCH" != "main" ]; then
  warn "checkout on '$BRANCH', not main — sync skipped (main must be the working branch)"
  exit 0
fi

# Fetch — offline is a loud (soft) state, not a silent skip
if ! git fetch --quiet origin 2>/dev/null; then
  warn "offline — sync state unverified"
  exit 0
fi

# Guard: tracked edits on main bypass the PR flow. Do NOT commit them — flag loudly.
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  alarm "main has uncommitted tracked edits — move them to a branch + PR; main must stay clean"
  exit 0
fi

# Guard: local commits ahead of origin bypass the PR flow.
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
if [ "$AHEAD" -gt 0 ]; then
  alarm "main is $AHEAD commit(s) ahead of origin (bypasses PR flow) — reset or move to a branch + PR"
  exit 0
fi

# Fast-forward to origin/main when behind.
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
if [ "$BEHIND" -gt 0 ]; then
  if git merge --ff-only --quiet origin/main 2>/dev/null; then
    clear_status
    note "synced (pulled $BEHIND)"
  else
    alarm "fast-forward failed — local main diverged; reset to origin/main"
    exit 0
  fi
else
  clear_status
fi

exit 0
