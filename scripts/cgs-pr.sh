#!/bin/bash
# cgs-pr — deliver a ~/.claude tracked-file change through the PR-only model.
#
# main stays a clean mirror of origin/main; edits never land on main directly. This helper
# wraps the repetitive branch -> worktree -> commit -> push -> PR -> auto-merge -> ff -> cleanup
# cycle (see rules/git-workflow.md § Репозиторий ~/.claude — PR-only).
#
# Usage:
#   cgs-pr new <slug>         Create worktree $HOME/cgs-<slug> on branch chore/<slug> from
#                             origin/main, print its path. Edit tracked files there.
#   cgs-pr ship "<title>"     Run FROM the worktree: commit any changes, push, open a PR,
#                             enable auto-merge (squash), wait until merged, then fast-forward
#                             the main checkout and remove the worktree + branch.
#
# Errors are loud and non-destructive: a stalled or unmergeable PR leaves the worktree intact
# for inspection rather than cleaning up. gh calls are bounded so a hung API can't freeze this.

set -uo pipefail

REPO="$HOME/.claude"
REMOTE_REPO="kirich1409/claude-global-settings"
POLL_TRIES=18          # 18 * 10s = 3 min max wait for auto-merge
POLL_INTERVAL=10

die()  { printf '⚠ cgs-pr: %s\n' "$*" >&2; exit 1; }
note() { printf '[cgs-pr] %s\n' "$*"; }

# Bound every network call so a hung API can't freeze the script. `timeout` is GNU coreutils
# (absent on stock macOS, where it ships as `gtimeout`); fall back to an unbounded gh if neither.
# Defined by availability to stay safe under bash 3.2 (macOS) — no empty-array expansion.
if command -v timeout >/dev/null 2>&1; then
  gh_to() { timeout 30 gh "$@"; }
elif command -v gtimeout >/dev/null 2>&1; then
  gh_to() { gtimeout 30 gh "$@"; }
else
  gh_to() { gh "$@"; }
fi

cmd_new() {
  local slug="${1:-}"
  [ -n "$slug" ] || die "usage: cgs-pr new <slug>"
  case "$slug" in */*|*' '*) die "slug must be kebab-case, no slashes/spaces";; esac
  local branch="chore/$slug" wt="$HOME/cgs-$slug"
  [ -e "$wt" ] && die "worktree path already exists: $wt"
  git -C "$REPO" fetch --quiet origin || die "fetch failed (network?)"
  git -C "$REPO" worktree add -b "$branch" "$wt" origin/main >/dev/null 2>&1 \
    || die "could not create worktree/branch (branch $branch may already exist)"
  note "worktree ready: $wt (branch $branch)"
  note "edit tracked files there, then run: cgs-pr ship \"<title>\""
  printf '%s\n' "$wt"
}

cmd_ship() {
  local title="${1:-}"
  # Must run from inside a worktree on a non-main branch.
  local top branch
  top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a git repo"
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$branch" = "main" ] && die "on main — run ship from a chore/<slug> worktree, not main"
  [ "$top" = "$REPO" ] && die "this is the main checkout — run ship from the worktree"
  [ -n "$title" ] || title="$branch"

  # Commit any pending changes.
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A || die "git add failed"
    git commit --quiet -m "$title" || die "commit failed"
    note "committed: $title"
  fi
  [ "$(git rev-list --count "origin/main..HEAD" 2>/dev/null || echo 0)" -gt 0 ] \
    || die "no commits ahead of origin/main — nothing to ship"

  git push --quiet -u origin "$branch" 2>/dev/null || die "push failed"
  note "pushed $branch"

  # Reuse an existing open PR for this branch; else create one (idempotent).
  local pr
  pr=$(gh_to pr list --repo "$REMOTE_REPO" --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)
  if [ -z "$pr" ]; then
    pr=$(gh_to pr create --repo "$REMOTE_REPO" --base main --head "$branch" \
          --title "$title" \
          --body "$(printf 'Delivered via cgs-pr.\n\n%s' "$(git log --oneline origin/main..HEAD)")" \
          2>/dev/null | grep -oE '[0-9]+$')
    [ -n "$pr" ] || die "PR create failed"
    note "opened PR #$pr"
  else
    note "reusing open PR #$pr"
  fi

  gh_to pr merge "$pr" --repo "$REMOTE_REPO" --auto --squash --delete-branch >/dev/null 2>&1 \
    || note "auto-merge request returned non-zero (may already be set, or PR instantly mergeable)"

  # Poll until merged.
  local state
  for _ in $(seq 1 "$POLL_TRIES"); do
    state=$(gh_to pr view "$pr" --repo "$REMOTE_REPO" --json state --jq '.state' 2>/dev/null)
    [ "$state" = "MERGED" ] && break
    [ "$state" = "CLOSED" ] && die "PR #$pr was CLOSED without merging — worktree kept for inspection"
    sleep "$POLL_INTERVAL"
  done
  if [ "$state" != "MERGED" ]; then
    die "PR #$pr not merged after $((POLL_TRIES*POLL_INTERVAL))s (check failing or branch stale) — worktree kept"
  fi
  note "PR #$pr merged"

  # Fast-forward the main checkout.
  git -C "$REPO" fetch --quiet origin || die "merged, but post-merge fetch failed — run csync"
  git -C "$REPO" merge --ff-only --quiet origin/main 2>/dev/null \
    || note "main checkout not on main or diverged — run csync manually"

  # Delete remote branch if --delete-branch didn't (delete_branch_on_merge may be off).
  if git -C "$REPO" ls-remote --heads origin "$branch" 2>/dev/null | grep -q .; then
    git -C "$REPO" push --quiet origin --delete "$branch" 2>/dev/null && note "deleted remote $branch"
  fi

  # Remove this worktree + branch from the main checkout (works even though cwd is the worktree).
  git -C "$REPO" worktree remove --force "$top" 2>/dev/null && note "removed worktree $top"
  git -C "$REPO" branch -D "$branch" 2>/dev/null && note "deleted local $branch"
  note "done — main at $(git -C "$REPO" log --oneline -1)"
}

case "${1:-}" in
  new)  shift; cmd_new "$@";;
  ship) shift; cmd_ship "$@";;
  *)    die "usage: cgs-pr {new <slug> | ship \"<title>\"}";;
esac
