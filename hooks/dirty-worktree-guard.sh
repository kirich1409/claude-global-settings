#!/bin/bash
# Dirty worktree guard: warns when there are uncommitted changes that may be from a previous task

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

# Determine the directory to check
if [ -n "$FILE_PATH" ] && [ -e "$(dirname "$FILE_PATH")" ]; then
    CHECK_DIR="$(dirname "$FILE_PATH")"
else
    CHECK_DIR="$(pwd)"
fi

# Check if we're in a git repo
git -C "$CHECK_DIR" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Check for uncommitted changes
DIRTY_COUNT=$(git -C "$CHECK_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY_COUNT" -gt 0 ]; then
    DIRTY_FILES=$(git -C "$CHECK_DIR" status --porcelain 2>/dev/null | head -5)
    echo "DIRTY WORKTREE: There are $DIRTY_COUNT uncommitted change(s) in this repo. These may be from a previous task:"
    echo "$DIRTY_FILES"
    if [ "$DIRTY_COUNT" -gt 5 ]; then
        echo "  ...and $((DIRTY_COUNT - 5)) more files"
    fi
    echo ""
    echo "Please confirm this is intentional before proceeding."
    exit 2
fi

exit 0
