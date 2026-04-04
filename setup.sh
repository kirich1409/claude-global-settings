#!/bin/bash
set -euo pipefail

REPO="git@github.com:kirich1409/claude-global-settings.git"
CLAUDE_DIR="$HOME/.claude"

add_csync_alias() {
  local rc="$HOME/.zshrc"
  [ -f "$HOME/.bashrc" ] && ! [ -f "$HOME/.zshrc" ] && rc="$HOME/.bashrc"
  if ! grep -q 'alias csync=' "$rc" 2>/dev/null; then
    echo 'alias csync="$HOME/.claude/hooks/sync-settings.sh"' >> "$rc"
    echo "Added csync alias to $rc"
  fi
}

echo "=== Claude Code Global Settings Setup ==="

# --- Already set up ---
if [ -d "$CLAUDE_DIR/.git" ]; then
  echo "Already configured. Pulling latest..."
  git -C "$CLAUDE_DIR" pull --rebase
  add_csync_alias
  echo "Done."
  exit 0
fi

# --- New machine ---
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "Cloning into ~/.claude ..."
  git clone "$REPO" "$CLAUDE_DIR"
  add_csync_alias
  echo "Done. Run 'claude' to start."
  exit 0
fi

# --- Existing machine ---
echo "Found existing ~/.claude. Backing up local files..."

BACKUP_DIR="/tmp/.claude-setup-backup-$$"
mkdir -p "$BACKUP_DIR"

for f in .credentials.json settings.local.json mcp-needs-auth-cache.json settings.json; do
  cp "$CLAUDE_DIR/$f" "$BACKUP_DIR/" 2>/dev/null || true
done
cp -r "$CLAUDE_DIR/channels" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$CLAUDE_DIR/plugins" "$BACKUP_DIR/" 2>/dev/null || true

cd "$CLAUDE_DIR"
git init
git remote add origin "$REPO"
git fetch origin
git reset --hard origin/main
git branch -M main
git branch --set-upstream-to=origin/main main

# Restore local-only files
for f in .credentials.json settings.local.json mcp-needs-auth-cache.json; do
  cp "$BACKUP_DIR/$f" "$CLAUDE_DIR/" 2>/dev/null || true
done
cp -r "$BACKUP_DIR/channels" "$CLAUDE_DIR/" 2>/dev/null || true
cp "$BACKUP_DIR/plugins/installed_plugins.json" "$CLAUDE_DIR/plugins/" 2>/dev/null || true
cp -r "$BACKUP_DIR/plugins/cache" "$CLAUDE_DIR/plugins/" 2>/dev/null || true
cp -r "$BACKUP_DIR/plugins/data" "$CLAUDE_DIR/plugins/" 2>/dev/null || true

add_csync_alias
echo ""
echo "Done. Backup at: $BACKUP_DIR"
