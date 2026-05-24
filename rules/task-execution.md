# Task Execution

## Error handling during tasks

For **blocking** errors (failures that prevent continuing). For investigation without a blocker, follow Communication Style (dig silently, report once).

1. Notify the user immediately that an error occurred.
2. Diagnose and attempt to fix autonomously.
3. Report what happened and what was done.
4. If one attempt is not enough — stop and ask the user how to proceed.

## Scope creep

If a task turns out significantly more complex than it appeared — stop, report what was found, propose to revise scope or approach before proceeding.

## Large output handling

For commands that may produce large output (test runs, git logs, build output, API responses, dependency trees) — prefer context-mode over raw Bash. The PreToolUse hook handles Bash automatically; explicitly use `mcp__plugin_context-mode_context-mode__execute` for large MCP tool results.
