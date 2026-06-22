#!/usr/bin/env bash
# PostToolUse:EnterWorktree — bootstrap the ast-index for a freshly-entered worktree.
#
# ast-index is per-worktree and does not carry over. SessionStart only indexes the
# session's initial CWD, so a worktree entered mid-session has no index — subagents
# then hit "Index not found" and fall back to grep. This hook rebuilds the index in
# the new worktree synchronously, so the index is ready before any delegation.
#
# Robust to the exact tool_response shape: tries known path fields, falls back to CWD.
# No-op-safe: `ast-index rebuild` fails silently in non-code repos (|| true).

set -u

INPUT="$(cat)"

# Capture the raw hook payload once, so the actual tool_response field name can be
# confirmed on first real worktree entry. Remove this line once verified.
printf '%s' "$INPUT" > /tmp/ast-index-worktree-hook.json 2>/dev/null || true

# Extract a plausible worktree path from the tool_response (then tool_input),
# checking the common field names. Empty string if nothing matches.
WT_PATH="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
def dig(obj):
    if not isinstance(obj, dict):
        return ""
    for k in ("worktreePath", "worktree_path", "path", "worktree", "dir", "cwd"):
        v = obj.get(k)
        if isinstance(v, str) and v:
            return v
    return ""
for key in ("tool_response", "toolResponse", "tool_input", "toolInput"):
    p = dig(d.get(key))
    if p:
        print(p)
        break
' 2>/dev/null || true)"

if [ -n "$WT_PATH" ] && [ -d "$WT_PATH" ]; then
  cd "$WT_PATH" 2>/dev/null || true
fi

# update is fast and incremental; rebuild bootstraps a missing index. Either is a
# no-op in a non-code repo. Synchronous on purpose: the index must be ready before
# the orchestrator delegates code search to subagents.
ast-index update 2>/dev/null || ast-index rebuild 2>/dev/null || true

# Keep the worktree index fresh for all subsequent edits (subagent / IDE / terminal)
# via a detached watcher. watch self-enforces a single instance per project, so a
# duplicate launch exits cleanly — no PID bookkeeping needed. Guarded on an existing
# index so it stays a no-op in non-code repos.
if ast-index stats >/dev/null 2>&1; then
  ( nohup ast-index watch >/dev/null 2>&1 & ) || true
fi
