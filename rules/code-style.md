---
paths:
  - "**/*.kt"
  - "**/*.java"
  - "**/*.swift"
  - "**/*.m"
  - "**/*.mm"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.py"
  - "**/*.go"
  - "**/*.rs"
  - "**/*.cs"
  - "**/*.c"
  - "**/*.cc"
  - "**/*.cpp"
  - "**/*.h"
  - "**/*.hpp"
  - "**/*.rb"
  - "**/*.php"
---

# Code Style

Planning-time code decisions: see `code-policies.md`.

## Code clarity and documentation

When code is modified, update directly related docs — KDoc, inline comments, `.md` files. Never leave docs describing something the code no longer does.

### Mandatory inline comments

Add a short comment whenever the code contains:

- **Preserved behavior from a migration** — old API used system default timezone, new API could use UTC but intentionally doesn't; old code had no null-check and callers rely on that. Comment: what the old code did and why the new matches it.
- **Intentionally retained bug or quirk** — known incorrect/surprising behavior kept for compat, spec compliance, or because fixing it would break something else. Comment: what the bug is, why it's kept.
- **Non-obvious constraint** — code looks wrong but is correct due to an external contract, hardware quirk, server format, third-party library, or platform limitation.
- **Implicit semantic change** — logic appears equivalent but subtly differs in edge cases (overflow, timezone, locale, rounding, encoding). Comment: what differs and why it's acceptable.

Format: one or two lines, lead with the surprising fact, follow with the reason. No need to reference the task or PR.

## Legacy code

Do not change code outside the scope of the current task unless it's a direct blocker.

When the task touches legacy code:
- Legacy pattern works and doesn't conflict → keep it, note in one line.
- Adding new code nearby → prefer current project standard, not legacy style.
- Legacy pattern actively blocks the task or mixing styles creates inconsistency → refactor as part of the task and explain why.

Threshold: does leaving it as-is make the result worse or harder to maintain?
