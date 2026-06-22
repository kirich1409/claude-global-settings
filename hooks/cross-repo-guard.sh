#!/bin/bash
# Cross-repo guard: warns when editing a file outside the current git repo/worktree

# Read the tool input from stdin
INPUT=$(cat)

# Find the file path
FILE_PATH=""
if echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null | read -r path; then
    FILE_PATH="$path"
fi

if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path', d.get('filePath','')))" 2>/dev/null)
fi

# Need both a file path and a current git root
[ -z "$FILE_PATH" ] && exit 0

CWD_GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$CWD_GIT_ROOT" ] && exit 0

# Check if the file's directory exists
[ -e "$(dirname "$FILE_PATH")" ] || exit 0

FILE_GIT_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null)
[ -z "$FILE_GIT_ROOT" ] && exit 0

if [ "$CWD_GIT_ROOT" != "$FILE_GIT_ROOT" ]; then
    echo "CROSS-REPO: File '$FILE_PATH' belongs to a different git repo/worktree."
    echo "  Current worktree: $CWD_GIT_ROOT"
    echo "  File worktree:    $FILE_GIT_ROOT"
    echo ""
    echo "Please confirm this is intentional before proceeding."
    exit 2
fi

exit 0
