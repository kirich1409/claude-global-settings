#!/bin/bash
# Environment setup script for Claude Code on the web.
# Configure this as the "Setup script" in your Claude Cloud Environment settings.
#
# Installs global Claude settings (CLAUDE.md, rules, hooks, agents, skills)
# from kirich1409/claude-global-settings into ~/.claude of the cloud container.
#
# ~/.claude already exists when this runs — we overlay settings with rsync,
# which is why a plain `git clone ~/.claude` fails with exit 128.

set -euo pipefail

REPO="https://github.com/kirich1409/claude-global-settings.git"
TARGET="$HOME/.claude"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "[cloud-setup] Cloning global settings..."
git clone --quiet --depth=1 "$REPO" "$TMP"

echo "[cloud-setup] Installing into $TARGET ..."
rsync -a --exclude='.git/' "$TMP/" "$TARGET/"

chmod +x "$TARGET/hooks/"*.sh 2>/dev/null || true

echo "[cloud-setup] Done. Global Claude settings installed."
