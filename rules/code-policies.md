# Code Policies

## Code clarity and documentation

When code is modified, update directly related docs — KDoc, inline comments, `.md` files. Never leave docs describing something the code no longer does.

### Mandatory inline comments

Add a short comment whenever the code contains:

- **Preserved behavior from a migration** — old API used system default timezone, new API could use UTC but intentionally doesn't; old code had no null-check and callers rely on that. Comment: what the old code did and why the new matches it.
- **Intentionally retained bug or quirk** — known incorrect/surprising behavior kept for compat, spec compliance, or because fixing it would break something else. Comment: what the bug is, why it's kept.
- **Non-obvious constraint** — code looks wrong but is correct due to an external contract, hardware quirk, server format, third-party library, or platform limitation.
- **Implicit semantic change** — logic appears equivalent but subtly differs in edge cases (overflow, timezone, locale, rounding, encoding). Comment: what differs and why it's acceptable.

Format: one or two lines, lead with the surprising fact, follow with the reason. No need to reference the task or PR.

## Logging

See `rules/logging.md` — covers permanent vs temporary diagnostic logs, the `// TEMP-LOG` marker convention, mandatory logger system (no `println` / `console.log`), per-level semantics, and what never goes into a log.

## Feature flags and configuration

- **Feature flags:** never add proactively — that's a product decision. If the task clearly implies a flag, ask first.
- **Configuration:** follow the project's existing pattern. If none — put config in a dedicated config layer, no hardcoded values.

## Breaking changes

Make the change directly. Backward compatibility and migration are the user's responsibility unless asked. For public API, DB schema, or CLI interface — notify the user before proceeding.

## Architectural decisions

When a task allows multiple approaches:
1. Check existing project patterns — match if clear.
2. No clear pattern → present options with trade-offs, recommend with reasoning, then proceed.
3. No signal at all → apply best practices and project settings as default.

Never silently pick an approach when alternatives exist.

## Legacy code

Do not change code outside the scope of the current task unless it's a direct blocker.

When the task touches legacy code:
- Legacy pattern works and doesn't conflict → keep it, note in one line.
- Adding new code nearby → prefer current project standard, not legacy style.
- Legacy pattern actively blocks the task or mixing styles creates inconsistency → refactor as part of the task and explain why.

Threshold: does leaving it as-is make the result worse or harder to maintain?
