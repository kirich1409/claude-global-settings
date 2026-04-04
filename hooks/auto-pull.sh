#!/bin/bash
# Auto-pull ~/.claude settings on session start.
git -C "$HOME/.claude" pull --rebase --quiet 2>/dev/null || true
