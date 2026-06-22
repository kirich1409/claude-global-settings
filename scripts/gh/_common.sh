#!/bin/bash
# _common.sh — shared helpers for the gh/glab tracker scripts.
#
# Source it from each script:
#   source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
#
# Provides:
#   GH_REST_TIMEOUT / GH_GQL_TIMEOUT — per-call network budgets (seconds).
#   gh_with_timeout <secs> <cmd...>  — run a command under a hard wall-clock timeout so a hung
#                                      network call aborts instead of freezing the calling agent.
#
# WHY: every `gh` / `gh api` call is a synchronous network request with no built-in timeout. If the
# GitHub/GitLab API accepts the connection but stalls the response (secondary rate-limit hold, slow
# drain, network drop without RST), the process — and the agent waiting on it — hangs forever.
# macOS ships no `timeout`/`gtimeout`, so we fall back to a perl `alarm` wrapper.

# Idempotent source guard.
[[ -n "${_GH_COMMON_LOADED:-}" ]] && return 0
_GH_COMMON_LOADED=1

GH_REST_TIMEOUT="${GH_REST_TIMEOUT:-30}"
GH_GQL_TIMEOUT="${GH_GQL_TIMEOUT:-45}"

# gh_with_timeout <seconds> <command> [args...]
# Prefers gtimeout/timeout when present; otherwise perl alarm. Returns the child's exit code; a
# timeout surfaces as non-zero (124 from coreutils timeout, or 142 = 128+SIGALRM from perl).
gh_with_timeout() {
  local secs="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  elif command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  else
    # perl alarm: SIGALRM after $secs kills the exec'd child; exit 142 on timeout.
    perl -e 'my $s=shift; alarm $s; exec @ARGV or die "exec failed: $!\n"' "$secs" "$@"
  fi
}
