# Code Policies

Code-writing style/comments/legacy: see `code-style.md`.

## Logging

All logging policy lives in [[logging]] — single source. It covers permanent vs temporary diagnostic logs, the `// TEMP-LOG` convention, the mandatory logger system, per-level semantics, and redaction. Nothing about logging (incl. `// TEMP-LOG`) is duplicated here.

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

