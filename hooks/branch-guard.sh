#!/bin/bash
# Branch guard: warns when editing files on protected branches

# Read the tool input from stdin
INPUT=$(cat)

# Find the git root for the file being edited
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
BRANCH=$(git -C "$CHECK_DIR" branch --show-current 2>/dev/null)
if [ $? -ne 0 ]; then
    exit 0
fi

# Warn on protected branches
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] || [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "dev" ] || [ "$BRANCH" = "development" ]; then
    echo "BRANCH: You are on the '$BRANCH' branch. You usually work in a separate feature branch."
    echo "Please confirm this is intentional before proceeding."
    exit 2
fi

exit 0
