#!/bin/bash
# Auto-sync ~/.claude on session start: commit local edits, rebase on remote, push.
#
# Core invariant: NEVER fail silently. Every non-OK outcome is recorded loudly via three
# channels — ~/.claude/.sync-status (rendered in the statusline on every prompt), an OS
# notification on hard failures, and stdout (which Claude relays). The hook always exits 0
# so it can never break a Claude Code session, but it never stays silent about a problem.
#
# Phase 1 of the csync rework (see swarm-report/csync-pr-sync-plan.md): the previous version
# committed "[auto-pull] save local" but NEVER pushed — local changes sat unpushed until a
# manual csync, which is the root cause of "working on a stale version". This version pushes.

set -uo pipefail

REPO="$HOME/.claude"
STATUS="$REPO/.sync-status"

cd "$REPO" 2>/dev/null || exit 0

# Recursion guard: a `claude -p` spawned by csync's conflict resolver must not re-enter sync
# (its own SessionStart would trigger this hook again). csync exports CLAUDE_SYNC_ACTIVE=1.
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

# Commit local edits so rebase/push has a clean tree
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  if ! git add -A 2>/dev/null || ! git commit --quiet -m "[auto-pull] save local $(hostname -s)" 2>/dev/null; then
    alarm "cannot commit local edits — sync skipped; fix git state in ~/.claude"
    exit 0
  fi
fi

# Fetch — offline is a loud (soft) state, not a silent skip
if ! git fetch --quiet origin 2>/dev/null; then
  warn "offline — sync state unverified"
  exit 0
fi

UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo origin/main)
BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)

# Rebase local commits on top of remote when behind
if [ "$BEHIND" -gt 0 ]; then
  if ! git rebase --quiet "$UPSTREAM" 2>/dev/null; then
    git rebase --abort 2>/dev/null || true
    # Save remote versions of conflicting files for manual merge
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      git show "$UPSTREAM:$f" > "$REPO/$f.remote" 2>/dev/null || true
    done < <(git diff --name-only HEAD "$UPSTREAM" 2>/dev/null)
    alarm "merge conflict — remote saved as *.remote; merge them and run csync"
    exit 0
  fi
fi

# Push any local commits (the fix for the unpushed-commits root cause)
AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
if [ "$AHEAD" -gt 0 ]; then
  if git push --quiet 2>/dev/null; then
    clear_status
    note "synced (pushed $AHEAD, pulled $BEHIND)"
  else
    alarm "push failed — $AHEAD local commit(s) NOT synced; run csync"
    exit 0
  fi
else
  clear_status
  [ "$BEHIND" -gt 0 ] && note "synced (pulled $BEHIND)"
fi

exit 0
