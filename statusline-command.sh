#!/bin/bash
# Read all of stdin into a variable
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# ~/.claude sync warning — auto-pull.sh writes .sync-status on any non-OK sync outcome.
# Surfaced on every prompt so a stale/failed sync can never go unnoticed.
SYNC_WARN=""
if [ -s "$HOME/.claude/.sync-status" ]; then
    SYNC_WARN=" | ${RED}⚠ sync: $(tr -d '\n' < "$HOME/.claude/.sync-status")${RESET}"
fi

# Extract fields with jq, "// 0" provides fallback for null
MODEL=$(echo "$input" | jq -r '.model.display_name')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Build progress bar: printf -v creates a run of spaces, then
# ${var// /▓} replaces each space with a block character
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')

    GIT_STATUS=""
    [ "$STAGED" -gt 0 ] && GIT_STATUS="${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_STATUS="${GIT_STATUS}${YELLOW}~${MODIFIED}${RESET}"

    echo -e "[$MODEL] $BAR $PCT% | 📁 ${DIR##*/} | 🌿 $BRANCH $GIT_STATUS$SYNC_WARN"
else
    echo -e "[$MODEL] $BAR $PCT% | 📁 ${DIR##*/}$SYNC_WARN"
fi

echo ""