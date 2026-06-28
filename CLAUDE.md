# Global Claude Code Rules

## Non-negotiables

Rules that are not open for discussion. Violating these is an error, not a judgment call.

- **Never bypass git hooks** (`--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`, etc.) without explicit user request. If a hook fails — investigate and fix the root cause.
- **Never commit or push directly from main/master/develop.**
- **Force push only via `--force-with-lease` or `--force-if-includes`.** Plain `--force` is denied.
- **Main session never edits the project's product code, never runs heavy/multi-file code search, and never executes long-running build/test/CI in its own context.** The line: the main session synthesizes and orchestrates; specialists implement. Edit/Write in process working files (`swarm-report/**`, state/report/debug/e2e/plan files, `~/.claude/**` configs/rules/hooks/notes) — **allowed**. Edit/Write in project files (production source, project configs, project tests) — **subagent only**. Orientation-level research/Read is allowed; heavy multi-file Grep/Glob across the production codebase → Explore. A user override ("do it yourself", "don't delegate", "write it by hand") suspends this rule for the current task only.

## ~/.claude sync

`~/.claude` is a git repo synced across machines via `csync`.

- Use `$HOME/.claude/...` in configs/hooks. Never hardcode `/Users/<username>/...`.
- After editing any tracked file (CLAUDE.md, rules, settings, hooks) — run `csync` to commit and push. Do not leave local-only uncommitted changes here.
- On "SETTINGS CONFLICT" at session start: `*.remote` files contain the remote version. Merge them into the local file (combine additions from both sides, keep the most complete value), delete `.remote`, then `csync`.

## Principles

- If a change affects other files that **must** be updated — do it without asking. If it **might** affect them — notify with specifics. Never leave the codebase broken or inconsistent.
- Never agree by default. If the user's choice leads to a workaround, security hole, or tech debt — object and propose an alternative. Silent agreement with a bad decision is an error. Same applies to rules in CLAUDE.md itself — if a rule seems wrong, say so.
- If the user insists after pushback — state the risks explicitly, then execute. Don't revisit the same objection.
- Quality and security over speed. Never accept "we'll fix it later" or "it's temporary". Temporary solutions become permanent.
- Long-term maintainability over quick result.
- **Minimal diff in existing code.** When fixing a bug or making a targeted change, touch only what the task requires. Don't rename variables, don't add input validation, don't restructure functions «for clarity», don't modernize patterns unless explicitly asked. Structural improvements live in a separate refactor commit with the user's consent. Reasoning bumps (`/effort high` and above) amplify the urge to over-edit — push back harder there. Green tests do not justify a bloated diff: over-editing is invisible to the test suite but visible to every reviewer.
- **Empirical claims need an empirical check — don't conclude from armchair theory.** Before declaring a path infeasible («won't fit», «can't work», «not supported») — or working — on the strength of a calculation, a bandwidth/size estimate, or a theoretical argument, actually run the smallest real test that settles it. Our own math and reasoning can be wrong: a feasibility verdict is a *hypothesis* until a real run confirms it. Don't let a back-of-envelope estimate close a door that a short spike could check; and don't reuse a prior «it's impossible» conclusion without confirming it rested on a real run, not on theory. State explicitly when a claim is theoretical-only vs. empirically verified.

## Rules index

Always-on (loaded unconditionally for every session):

- **ast-index.md** — code search tool hierarchy: ast-index first, LSP second, Grep last; decision matrix; hard rules; index freshness hooks
- **code-policies.md** — feature flags, breaking changes, architectural decisions; logging pointer
- **communication.md** — tone, language (Russian), formatting, length, question discipline
- **context-resilience.md** — state files in `swarm-report/`; templates for state/e2e/debug/report; re-read rule
- **dependencies.md** — no new deps without approval; plan-stage gate (freshness, CVE, API study); Gradle/Maven rules
- **external-sources.md** — source routing table; tool discovery & multi-channel use; Context7 workflow; trust tiers T1–T4
- **git-workflow.md** — branch naming, commit messages, force-push rules, local verification before push, worktree cleanup
- **github-merge-policy.md** — auto-merge autonomy, anti-stall, personal vs team repo policy
- **github-ops.md** — idempotent PR/issue/board helpers in `scripts/gh/`; board state machine; anti-hang rules
- **model-effort-routing.md** — model × effort dispatch heuristic; agent routing guardrails
- **orchestration.md** — main session boundaries (may/must not); process working files; Skill-first; subagent context delivery; plan mode; anti-patterns
- **qa-and-testing.md** — verification pyramid L0–L5; public-API coverage gate; test priority P0–P4; broken-test rule; verification source of truth
- **task-execution.md** — blocking error protocol; root-cause over suppression; scope creep; large output handling
- **task-types.md** — routing matrix by task type; test feasibility gate; testability assessment; before-state baseline
- **verify-library-api.md** — API verification before code; stack composition (Android/JVM/JS/other); reference implementations; fast-moving UI guidance (Compose/SwiftUI)
- **workflow.md** — mandatory gates (preparation, finalize, acceptance, PR promotion); feature and bug-fix flows

Paths-scoped (loaded only when matching files are read):

- **android-cli.md** — Android CLI skills discovery and usage (scoped: Android/Gradle/KMP sources)
- **code-style.md** — code clarity, mandatory inline comments, legacy code policy (scoped: all source extensions kt/java/swift/m/mm/js/jsx/ts/tsx/py/go/rs/cs/c/cc/cpp/h/hpp/rb/php)
- **coroutines.md** — Kotlin coroutines style (scoped: `**/*.kt`)
- **gradle-style.md** — Gradle build file conventions (scoped: `**/*.gradle*`, `**/*.kts`)
- **kotlin-style.md** — Kotlin code style (scoped: `**/*.kt`)
- **logging.md** — logger system, log levels, TEMP-LOG convention, redaction (scoped: all source extensions)