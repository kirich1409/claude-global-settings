#!/bin/bash
# Auto-pull ~/.claude settings on first tool call per session.
# Uses a 1-hour cooldown to avoid repeated pulls within the same session.
# Runs git pull in background to not block the tool call.

STAMP="/tmp/.claude-settings-pull"
NOW=$(date +%s)
LAST=$(stat -f%m "$STAMP" 2>/dev/null || echo 0)

if [ $(( NOW - LAST )) -gt 3600 ]; then
  touch "$STAMP"
  git -C "$HOME/.claude" pull --rebase --quiet 2>/dev/null &
fi
