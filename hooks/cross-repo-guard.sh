#!/bin/bash
# Cross-repo guard: warns when editing a file outside the current git repo/worktree

# Read the tool input from stdin
INPUT=$(cat)

if ! command -v python3 >/dev/null 2>&1; then
    echo "WARN: python3 not found — cross-repo-guard cannot parse tool input, skipping check" >&2
fi

# Find the file path. Claude Code wraps tool arguments under tool_input (top-level
# fallback kept for older payloads); NotebookEdit uses notebook_path instead of file_path.
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', d)
    print(ti.get('file_path') or ti.get('filePath') or ti.get('notebook_path') or ti.get('notebookPath') or '')
except Exception:
    print('')
" 2>/dev/null)

# Need both a file path and a current git root
[ -z "$FILE_PATH" ] && exit 0

CWD_GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$CWD_GIT_ROOT" ] && exit 0

# Check if the file's directory exists
[ -e "$(dirname "$FILE_PATH")" ] || exit 0

FILE_GIT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null)
[ -z "$FILE_GIT_ROOT" ] && exit 0

if [ "$CWD_GIT_ROOT" != "$FILE_GIT_ROOT" ]; then
    echo "CROSS-REPO: File '$FILE_PATH' belongs to a different git repo/worktree." >&2
    echo "  Current worktree: $CWD_GIT_ROOT" >&2
    echo "  File worktree:    $FILE_GIT_ROOT" >&2
    echo "" >&2
    echo "Please confirm this is intentional before proceeding." >&2
    exit 2
fi

exit 0
