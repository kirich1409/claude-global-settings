#!/bin/bash
# validate-config-on-edit — PostToolUse(Edit|Write) hook.
#
# Instant enforcement of the default-distrust principle for config artifacts:
# whenever settings*.json inside the claude-global-settings repo (main checkout
# or any of its worktrees) is edited, run scripts/validate-config.sh immediately
# and feed failures back to the agent — without waiting for the CI gate on the PR.
#
# Exit 2 + stderr = feedback delivered to the agent (PostToolUse cannot block the
# already-applied edit, but the agent must fix findings before shipping).

set -u

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)

case "$FILE" in
  */settings.json|*/settings.local.json) ;;
  *) exit 0 ;;
esac

REPO_ROOT=$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null) || exit 0
VALIDATOR="$REPO_ROOT/scripts/validate-config.sh"
# Only the claude-global-settings repo carries this validator; other repos' settings
# files are their own project's concern.
[ -f "$VALIDATOR" ] || exit 0

OUT=$(cd "$REPO_ROOT" && bash "$VALIDATOR" 2>&1)
if [ $? -ne 0 ]; then
  {
    echo "validate-config FAILED after editing $FILE — fix before shipping:"
    printf '%s\n' "$OUT" | grep '^✗' || printf '%s\n' "$OUT"
  } >&2
  exit 2
fi
exit 0
