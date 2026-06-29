#!/bin/bash
# bootstrap-machine.sh — converge this machine onto the PR-only ~/.claude line.
#
# Brings a machine's ~/.claude checkout in sync with the canonical origin/main (new pull-only
# csync/auto-pull + rules + helpers) and checks it can deliver changes via PR. Idempotent —
# safe to re-run. See rules/git-workflow.md § Репозиторий ~/.claude — PR-only.
#
# Usage:
#   bootstrap-machine.sh            Safe mode: fast-forward main; STOP loudly if the checkout
#                                   has local commits or uncommitted tracked edits (so nothing
#                                   is lost). Resolve those into a PR, then re-run.
#   bootstrap-machine.sh --force    Discard local tracked state and hard-reset to origin/main.
#                                   Untracked files (memory, .remember, swarm-report, agent-memory)
#                                   are preserved either way.
#
# Run OUTSIDE an active Claude session (the SessionStart auto-pull hook would race it).

set -uo pipefail

REPO="$HOME/.claude"
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

die()  { printf '⚠ bootstrap: %s\n' "$*" >&2; exit 1; }
ok()   { printf '✓ %s\n' "$*"; }
note() { printf '  %s\n' "$*"; }

[ -d "$REPO/.git" ] || die "$REPO is not a git repo"
cd "$REPO" || die "cannot cd to $REPO"
git remote get-url origin >/dev/null 2>&1 || die "no 'origin' remote configured"

# Clean up stale rebase state from a previous crash.
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  git rebase --abort 2>/dev/null || true
fi

git fetch --quiet origin || die "fetch failed (network? gh/git auth?)"
ok "fetched origin"

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
dirty=0; { ! git diff --quiet || ! git diff --cached --quiet; } && dirty=1
ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)

if [ "$FORCE" -eq 1 ]; then
  # Destructive path: announce exactly what is discarded before doing it.
  [ "$branch" != "main" ] && note "switching from '$branch' to main"
  [ "$ahead" -gt 0 ] && note "discarding $ahead local commit(s) not on origin/main"
  [ "$dirty" -eq 1 ] && note "discarding uncommitted tracked edits"
  git checkout --quiet -B main origin/main 2>/dev/null || die "checkout main failed"
  git reset --hard --quiet origin/main || die "reset failed"
  ok "hard-reset main to origin/main"
else
  # Safe path: refuse to clobber un-delivered local work.
  if [ "$branch" != "main" ]; then
    die "checkout is on '$branch', not main. Switch to main (git checkout main) or use --force."
  fi
  if [ "$dirty" -eq 1 ]; then
    die "uncommitted tracked edits on main — deliver them via a branch+PR (scripts/cgs-pr.sh), or re-run with --force to discard."
  fi
  if [ "$ahead" -gt 0 ]; then
    die "$ahead local commit(s) ahead of origin/main — deliver them via PR, or re-run with --force to discard."
  fi
  behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
  if [ "$behind" -gt 0 ]; then
    git merge --ff-only --quiet origin/main || die "fast-forward failed unexpectedly"
    ok "fast-forwarded main ($behind commit(s))"
  else
    ok "main already up to date"
  fi
fi

note "main at $(git log --oneline -1)"

# gh auth — needed to open PRs from this machine. Warn only; never launch interactive login.
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    ok "gh authenticated"
  else
    note "⚠ gh NOT authenticated — run: gh auth login  (required to open PRs from here)"
  fi
else
  note "⚠ gh CLI not installed — install it to open PRs from here"
fi

# Local aliases (~/.zshrc is NOT synced) — add idempotently.
ZSHRC="$HOME/.zshrc"
add_alias() { # name -> target
  local name="$1" target="$2"
  if [ -f "$ZSHRC" ] && grep -q "alias $name=" "$ZSHRC" 2>/dev/null; then
    return 0
  fi
  printf 'alias %s="%s"\n' "$name" "$target" >> "$ZSHRC"
  note "added alias '$name' to ~/.zshrc"
}
add_alias csync '$HOME/.claude/hooks/sync-settings.sh'
add_alias cgspr '$HOME/.claude/scripts/cgs-pr.sh'
ok "aliases ensured (run 'source ~/.zshrc' or open a new shell)"

# The SessionStart auto-pull hook lives in settings.json (tracked) — already in place after sync.
printf '\nDone. This machine is on the PR-only line. Edits go through scripts/cgs-pr.sh (branch -> PR -> auto-merge).\n'
