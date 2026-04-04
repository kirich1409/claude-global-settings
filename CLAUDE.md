@RTK.md

## ~/.claude portability

This directory is a git repo synced across machines. When editing `settings.json`, hooks, or any config here, use `$HOME/.claude/...` instead of absolute paths like `/Users/<username>/...`. Never hardcode the home directory path.

## Gradle / JVM Dependencies

Avoid directly accessing `.gradle` files or directories. Instead, proactively use the `ksrc` bash tool to inspect source code of dependencies and learn API shapes or implementations. Start with `ksrc --help`.
