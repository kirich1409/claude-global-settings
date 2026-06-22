#!/bin/bash
set -euo pipefail

REPO="https://github.com/kirich1409/claude-global-settings.git"
CLAUDE_DIR="$HOME/.claude"

add_csync_alias() {
  local rc=""
  case "${SHELL:-}" in
    */zsh)  rc="$HOME/.zshrc" ;;
    */bash) rc="$HOME/.bashrc" ;;
    *)
      echo "Add this alias to your shell profile manually:"
      echo '  alias csync="$HOME/.claude/hooks/sync-settings.sh"'
      return ;;
  esac
  if ! grep -q 'alias csync=' "$rc" 2>/dev/null; then
    echo 'alias csync="$HOME/.claude/hooks/sync-settings.sh"' >> "$rc"
    echo "Added csync alias to $rc. Run: source $rc"
  fi
}

# Register the structural JSON merge driver in this clone's .git/config.
# .git/config is per-clone and never synced, so every machine must register it itself.
# Referenced by .gitattributes (settings.json merge=json). Idempotent.
register_merge_driver() {
  git -C "$CLAUDE_DIR" config merge.json.name "structural 3-way JSON merge"
  git -C "$CLAUDE_DIR" config merge.json.driver \
    'python3 $HOME/.claude/hooks/json-3way-merge.py %O %A %B'
}

echo "=== Claude Code Global Settings Setup ==="

# --- Already set up ---
if [ -d "$CLAUDE_DIR/.git" ]; then
  echo "Already configured. Pulling latest..."
  if ! git -C "$CLAUDE_DIR" pull --rebase; then
    echo "Pull failed. Try: cd ~/.claude && git rebase --abort && git pull --rebase"
    exit 1
  fi
  register_merge_driver
  add_csync_alias
  echo "Done."
  exit 0
fi

# --- New machine ---
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "Cloning into ~/.claude ..."
  git clone "$REPO" "$CLAUDE_DIR"
  register_merge_driver
  add_csync_alias
  echo "Done. Run 'claude' to start."
  exit 0
fi

# --- Existing machine ---
echo "Found existing ~/.claude. Backing up..."

BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
cp -a "$CLAUDE_DIR" "$BACKUP_DIR"
echo "Full backup saved to $BACKUP_DIR"

# Rollback on failure
cleanup_on_failure() {
  echo "Setup failed. Removing partial git state..."
  rm -rf "$CLAUDE_DIR/.git"
  echo "Your original files are intact. Backup at: $BACKUP_DIR"
}
trap cleanup_on_failure ERR

cd "$CLAUDE_DIR"
git init
git remote add origin "$REPO"
git fetch origin
git reset --hard origin/main
git branch -M main
git branch --set-upstream-to=origin/main main

register_merge_driver

trap - ERR

# Restore local-only files from backup
for f in .credentials.json settings.local.json mcp-needs-auth-cache.json; do
  [ -f "$BACKUP_DIR/$f" ] && cp "$BACKUP_DIR/$f" "$CLAUDE_DIR/"
done
[ -d "$BACKUP_DIR/channels" ] && cp -r "$BACKUP_DIR/channels" "$CLAUDE_DIR/"
[ -f "$BACKUP_DIR/plugins/installed_plugins.json" ] && cp "$BACKUP_DIR/plugins/installed_plugins.json" "$CLAUDE_DIR/plugins/"
[ -d "$BACKUP_DIR/plugins/cache" ] && cp -r "$BACKUP_DIR/plugins/cache" "$CLAUDE_DIR/plugins/"
[ -d "$BACKUP_DIR/plugins/data" ] && cp -r "$BACKUP_DIR/plugins/data" "$CLAUDE_DIR/plugins/"

add_csync_alias
echo ""
echo "Done. Backup at: $BACKUP_DIR"
