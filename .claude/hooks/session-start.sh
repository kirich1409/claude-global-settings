#!/bin/bash
# SessionStart hook: installs global Claude settings in Cloud sessions
# that don't have an Environment setup script configured.
#
# If you configured cloud-setup.sh as your Environment setup script,
# settings are already installed — this hook detects that and skips.
#
# Add this hook to any project's .claude/settings.json to get global
# settings applied even without a dedicated Cloud Environment.

set -euo pipefail

# Only run in Cloud; local machines have ~/.claude already
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO="https://github.com/kirich1409/claude-global-settings.git"
TARGET="$HOME/.claude"

# If Environment setup script already ran, settings are in place
if [ -f "$TARGET/CLAUDE.md" ] && [ -d "$TARGET/rules" ]; then
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git clone --quiet --depth=1 "$REPO" "$TMP" 2>/dev/null || exit 0
rsync -a --exclude='.git/' "$TMP/" "$TARGET/"
chmod +x "$TARGET/hooks/"*.sh 2>/dev/null || true
