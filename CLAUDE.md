@RTK.md

## ~/.claude portability

This directory is a git repo synced across machines. When editing `settings.json`, hooks, or any config here, use `$HOME/.claude/...` instead of absolute paths like `/Users/<username>/...`. Never hardcode the home directory path.

## ~/.claude settings conflict resolution

If you see "SETTINGS CONFLICT" in the session start message, there are `*.remote` files in `~/.claude/` containing the remote version of conflicting config files. You must:

1. Read both the local file and its `.remote` counterpart
2. Intelligently merge them — combine additions from both sides, keep the most complete version of each setting
3. Write the merged result to the local file
4. Delete the `.remote` file
5. Run `$HOME/.claude/hooks/sync-settings.sh` to commit and push the merged result

## Gradle / JVM Dependencies

Avoid directly accessing `.gradle` files or directories. Instead, proactively use the `ksrc` bash tool to inspect source code of dependencies and learn API shapes or implementations. Start with `ksrc --help`.
