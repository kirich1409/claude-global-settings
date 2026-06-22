#!/usr/bin/env bash
# SessionEnd — stop this project's `ast-index watch` daemon, if one is running.
#
# Counterpart to the SessionStart launcher. Reaps the per-project watcher so idle
# daemons don't linger after a session closes. Best-effort: Claude Code's SessionEnd
# is unreliable (does NOT fire on /exit or /clear, may be killed on Ctrl+C, and never
# fires on a hard terminal kill — see anthropics/claude-code#17885, #6428, #32712).
# A leaked watcher is harmless: it is bounded to one per project (watch self-enforces
# a single instance) and a stale lock self-heals on the next SessionStart relaunch.
#
# Targeting: the watcher is matched by its working directory, NOT by the watch lock —
# the lock file's stored PID proved unreliable (can point at a dead/wrong PID). Every
# `ast-index watch` runs with cwd == its project root, so we enumerate ast-index
# processes and kill the watcher whose cwd equals this session's project dir.
#
# Scope: only the project at the session's cwd. Worktree watchers (separate cwds) are
# not reaped here — they are likewise bounded to one each and exit when their worktree
# is removed.

set -u

payload="$(cat)"

cwd="$(printf '%s' "$payload" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("cwd",""))
except Exception: pass' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"

# The config repo never gets a watcher (SessionStart excludes it) — nothing to reap.
[ "$cwd" = "$HOME/.claude" ] && exit 0

# Normalize to a physical path so symlinked dirs match lsof's physical cwd output.
target="$(cd "$cwd" 2>/dev/null && pwd -P)"
[ -n "$target" ] || exit 0

command -v lsof >/dev/null 2>&1 || exit 0

for pid in $(pgrep -x ast-index 2>/dev/null); do
  # Only the long-lived watcher, not a transient `ast-index update`/`stats` invocation.
  cmd="$(ps -o command= -p "$pid" 2>/dev/null)"
  case "$cmd" in
    *"ast-index watch"*) ;;
    *) continue ;;
  esac
  pcwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
  [ "$pcwd" = "$target" ] && kill "$pid" 2>/dev/null || true
done

exit 0
