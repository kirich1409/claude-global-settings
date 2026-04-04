#!/bin/bash
set -euo pipefail

REPO="git@github.com:kirich1409/claude-global-settings.git"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="/tmp/.claude-setup-backup-$$"

echo "=== Claude Code Global Settings Setup ==="
echo ""

# --- Already set up? ---
if [ -d "$CLAUDE_DIR/.git" ]; then
  echo "Already a git repo. Pulling latest..."
  git -C "$CLAUDE_DIR" pull --rebase
  echo "Done."
  exit 0
fi

# --- New machine (no ~/.claude) ---
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "No ~/.claude found. Cloning..."
  git clone "$REPO" "$CLAUDE_DIR"
  echo ""
  echo "Done. Run 'claude' to start — it will create local files automatically."
  exit 0
fi

# --- Existing machine (has ~/.claude but not a git repo) ---
echo "Found existing ~/.claude — will overlay shared settings."
echo ""

# Backup local-only files
echo "Backing up local files to $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
cp "$CLAUDE_DIR/.credentials.json" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$CLAUDE_DIR/channels" "$BACKUP_DIR/" 2>/dev/null || true
cp "$CLAUDE_DIR/settings.local.json" "$BACKUP_DIR/" 2>/dev/null || true
cp "$CLAUDE_DIR/mcp-needs-auth-cache.json" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$CLAUDE_DIR/plugins" "$BACKUP_DIR/" 2>/dev/null || true

# Save old settings.json for reference
cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/settings.json.old" 2>/dev/null || true

# Init git and pull shared settings
echo "Initializing git and pulling shared settings..."
cd "$CLAUDE_DIR"
git init
git remote add origin "$REPO"
git fetch origin
git reset --hard origin/main
git branch -M main
git branch --set-upstream-to=origin/main main

# Restore local-only files
echo "Restoring local files..."
cp "$BACKUP_DIR/.credentials.json" "$CLAUDE_DIR/" 2>/dev/null || true
cp -r "$BACKUP_DIR/channels" "$CLAUDE_DIR/" 2>/dev/null || true
cp "$BACKUP_DIR/settings.local.json" "$CLAUDE_DIR/" 2>/dev/null || true
cp "$BACKUP_DIR/mcp-needs-auth-cache.json" "$CLAUDE_DIR/" 2>/dev/null || true
# Restore full plugins dir (installed_plugins.json, cache, data)
cp -r "$BACKUP_DIR/plugins/installed_plugins.json" "$CLAUDE_DIR/plugins/" 2>/dev/null || true
cp -r "$BACKUP_DIR/plugins/cache" "$CLAUDE_DIR/plugins/" 2>/dev/null || true
cp -r "$BACKUP_DIR/plugins/data" "$CLAUDE_DIR/plugins/" 2>/dev/null || true

echo ""
echo "Done. Backup of old files is at: $BACKUP_DIR"
echo ""
echo "Review your old settings.json if needed:"
echo "  diff $BACKUP_DIR/settings.json.old $CLAUDE_DIR/settings.json"
echo ""
echo "Add csync alias to your shell profile:"
echo '  echo '\''alias csync="\$HOME/.claude/hooks/sync-settings.sh"'\'' >> ~/.zshrc'
