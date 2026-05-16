#!/bin/bash
# Branch guard: warns when editing files on protected branches
# Exceptions:
#   - ~/.claude config repo is always edited on main
#   - Gitignored files (non-persistent changes) don't require a worktree

INPUT=$(cat)

# Extract file_path from tool_input (Claude Code wraps tool arguments under tool_input)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', d)
    print(ti.get('file_path', ti.get('filePath', '')))
except Exception:
    print('')
" 2>/dev/null)

# Skip global scratch dir — see ~/.claude/CLAUDE.md § Context compaction resilience.
# Hardcoded to bypass git/.gitignore checks that fail when hook cwd is unrelated to target repo.
case "$FILE_PATH" in
    */swarm-report/*|swarm-report/*) exit 0 ;;
esac

# Determine the directory to check
if [ -n "$FILE_PATH" ] && [ -e "$(dirname "$FILE_PATH")" ]; then
    CHECK_DIR="$(dirname "$FILE_PATH")"
else
    CHECK_DIR="$(pwd)"
fi

# Skip for ~/.claude config repo — always works on main
GIT_ROOT=$(git -C "$CHECK_DIR" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ] && [ "$(cd "$GIT_ROOT" 2>/dev/null && pwd -P)" = "$(cd "$HOME/.claude" 2>/dev/null && pwd -P)" ]; then
    exit 0
fi

# Check if we're in a git repo
BRANCH=$(git -C "$CHECK_DIR" branch --show-current 2>/dev/null)
if [ $? -ne 0 ]; then
    exit 0
fi

# Skip if the file is gitignored — non-persistent changes don't need a worktree
if [ -n "$FILE_PATH" ] && git -C "$CHECK_DIR" check-ignore -q "$FILE_PATH" 2>/dev/null; then
    exit 0
fi

# Warn on protected branches
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] || [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "dev" ] || [ "$BRANCH" = "development" ]; then
    echo "BRANCH: You are on the '$BRANCH' branch. You usually work in a separate feature branch." >&2
    echo "Please confirm this is intentional before proceeding." >&2
    exit 2
fi

exit 0
