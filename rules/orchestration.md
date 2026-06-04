# Orchestration Rules

Main session = orchestrator. It runs on the most capable (and expensive) model — its value is in reasoning, planning, and synthesis. Hands-on coding belongs to cheaper Sonnet/Haiku specialists; keep the main session for decisions.

The main session **may** do research, edit process working files (state/report/debug/plan, `~/.claude/**`), and synthesize results. The main session **must not** edit the project's production code, do heavy code search across the codebase, or wait on long-running build/test/CI in its own context.

## What the main session does

- Frame the task and hold the overall plan.
- Orientation-level research: Read (1–N, until focus starts to drift), targeted Bash commands, MCP/web lookups (`mcp__plugin_context7_*`, single-page `WebFetch`, etc.).
- `git status` / `git log` / `ls` / `pwd` / trivial shell.
- **Edit / Write in process working files** (see table below).
- Plan synthesis from Explore and specialist summaries.
- Final synthesis of results and the user-facing answer.
- Skill / Agent invocation with the right model.

### Process working files (main session edits these directly)

| Category | Examples |
|---|---|
| State / reports / debug logs | `swarm-report/<slug>-state.md`, `<slug>-report.md`, `<slug>-debug.md`, `<slug>-e2e-scenario.md` |
| Plan files in plan mode | files created in the current plan mode |
| Session notes | `MEMORY.md`, files in `memory/`, scratch files for the current task |
| Global rules and configs | `~/.claude/CLAUDE.md`, `~/.claude/rules/**`, `~/.claude/settings*.json`, hooks |
| Process documentation | READMEs / docs inside `~/.claude`, plugin tooling for agents |

These are **process** files, not project code. The main session owns them — editing them is part of orchestration, not implementation.

## What the main session is forbidden from doing

Hard rules, not guidance. A violation is an error (see `CLAUDE.md § Non-negotiables`).

- **Forbidden:** Edit / Write in **project code** (production source, project configs, project tests). Delegation is mandatory even for a single line.
- **Forbidden:** heavy / multi-file grep / deep code search across the production codebase → Explore (haiku). A targeted `grep` in one or two files for orientation is fine.
- **Forbidden:** running long-running build / test / CI in the main context → general-purpose in background.
- **Forbidden:** review tasks (security / performance / UX / code review) inside the main session → the matching expert agent.

### STOP check before a tool call

Before every `Edit` / `Write` / non-trivial `Grep` / `Glob` / `Bash` — **STOP** and answer:

1. What am I touching? **Project code** or **mass file reads across the codebase** → subagent.
2. A process working file (see table) or `~/.claude/**` → main session is fine.
3. Lightweight orientation (a few Reads, `git status`/`log`/`ls`, targeted grep for routing) → main session is fine.

If the task needs N edits in production code, that is not "many small ones from the main session" — it is one job for a specialist.

## Skill-first

If a task matches an installed skill — use the skill. Skills already know the right sequence of agents and models. Direct Agent invocation is a fallback when no skill fits.

Examples: implementation flow → `/check` + `/finalize` + `/acceptance` + `/create-pr` + `/drive-to-merge`; new spec → `/write-spec`; UI migration → `/migrate-to-compose`; tests → `/write-tests`.

## Subagent code-search instructions

Subagents do **not** inherit `~/.claude/rules/**` (including `rules/ast-index.md`) — they default to Grep/Read unless told otherwise. When delegating any task that searches or reads code (Explore, general-purpose, specialists), include an explicit ast-index directive in the prompt:

> Use `ast-index` via Bash for code search before Grep: `search "q"`, `file "Name"`, `class "Name"`, `usages "Name"`, `implementations "Name"`, `callers "fn"`. Grep only when ast-index returns empty or for regex / string-literal search. Before `Read` on a file longer than ~500 lines, run `ast-index outline <file>` and Read only the targeted slice via `offset`/`limit`. On "Index not found" → `ast-index rebuild`, never fall back to Grep.

The index itself is kept fresh automatically by hooks (see `rules/ast-index.md` → Index Freshness); this rule only ensures the subagent *uses* it.

## Routing matrix (task type → agent → model)

The model is passed explicitly via the Agent tool's `model:` parameter.

| Task type | Agent | Model |
|---|---|---|
| Code research, navigation, "find X / where is Y used" | Explore | haiku |
| Architectural design, decomposition, API design between layers | `developer-workflow-experts:architecture-expert` / Plan | opus |
| Security review (auth, crypto, storage, network) | `developer-workflow-experts:security-expert` | opus |
| Performance review (profiling, hot paths, recomposition) | `developer-workflow-experts:performance-expert` | opus |
| UX review (screens, flows, a11y) | `developer-workflow-experts:ux-expert` | opus |
| Debugging investigation (root cause, stack traces, binary search over changes) | `developer-workflow-experts:debugging-expert` | opus |
| Build engineering (Gradle, AGP, KMP, version catalogs) | `developer-workflow-experts:build-engineer` | sonnet (opus for complex restructuring) |
| DevOps (CI/CD, packaging, dependency scanning) | `developer-workflow-experts:devops-expert` | sonnet |
| Business / product analysis (scope, MVP, ACs, trade-offs) | `developer-workflow-experts:business-analyst` | opus |
| Code review (semantic, pre-PR) | `developer-workflow-experts:code-reviewer` / `pr-review-toolkit:code-reviewer` | sonnet (opus for security-sensitive PRs) |
| Comment-quality review | `pr-review-toolkit:comment-analyzer` | sonnet |
| Test coverage review | `pr-review-toolkit:pr-test-analyzer` | sonnet |
| Silent failure / error-handling hunt | `pr-review-toolkit:silent-failure-hunter` | sonnet |
| Type design review | `pr-review-toolkit:type-design-analyzer` | sonnet |
| Implementation Kotlin / Android (ViewModel/UseCase/Repository/DI/mappers/unit tests) | `developer-workflow-kotlin:kotlin-engineer` | sonnet |
| Compose UI (composables, theme, navigation, modifiers, previews) | `developer-workflow-kotlin:compose-developer` | sonnet |
| Refactor / simplification pass | `code-simplifier:code-simplifier` / `pr-review-toolkit:code-simplifier` | sonnet |
| Manual QA against a running app | `developer-workflow:manual-tester` | sonnet |
| Plugin / skill / agent authoring | `plugin-dev:plugin-validator` / `plugin-dev:agent-creator` / `plugin-dev:skill-reviewer` | sonnet |
| Hook authoring analysis | `hookify:conversation-analyzer` | sonnet |
| Claude Code / SDK / API "how do I" | `claude-code-guide` | sonnet |
| Build / test / CI runs (idempotent, long-running) | general-purpose | sonnet (haiku if pure shell + log assembly) |
| GitLab / GitHub admin (open an issue, attach a label, leave a comment) | general-purpose | haiku |
| Lookups via MCP / web / docs (one page + summary) | general-purpose | haiku |

For any PR/MR, issue, or Projects-board work (incl. delegated `gh`/`glab` calls): use the idempotent,
timeout-safe toolkit in `$HOME/.claude/scripts/gh/` and follow `rules/github-ops.md` (mechanics) +
`rules/github-merge-policy.md` (autonomy / anti-stall / per-project policy). Never block the main
session on `gh run watch` / `gh pr checks --watch`.

## Model selection rules (when the task is not in the table)

- `opus` — reasoning, planning, synthesis, multi-factor analysis, security / perf / UX / architecture review, debugging root cause.
- `sonnet` — implementation, refactor, code review, manual QA, build engineering, mid-complexity specialist tasks.
- `haiku` — search, lookups, admin CRUD, file discovery, mechanical transforms.

When the choice between two adjacent models is unclear — pick the **smaller** one. Bump to the larger model on the first failure or poor-quality result.

## Effort level

`/effort` sets how hard the main session thinks. Per-session and persisted across restarts; subagents do **not** inherit it. Opus 4.7 levels: `low | medium | high | xhigh | max`.

- `xhigh` / `max` — planning, architecture, security review, debugging root cause, ambiguous trade-offs.
- `high` / `medium` — day-to-day orchestration and routing.
- `low` — narrow targeted edits, mechanical refactors, doc fixes, simple navigation. Reasoning bumps amplify «over-editing» (the model rewrites more than the bug needs); on small fixes a lower level yields a cleaner diff and is often faster.

Persist non-default values via `~/.claude/settings.json: "effortLevel"` or env `CLAUDE_CODE_EFFORT_LEVEL` (env wins). `max` does not persist across sessions — set it explicitly each time.

**Subagent invocations.** Subagents do not inherit the main session's effort. Always pass an explicit `model:` via the Agent tool. Where the agent definition or invocation also exposes an effort parameter — pass it explicitly, matched to task complexity (planning / architecture → `xhigh`+; implementation / review → `medium` / `high`; mechanical lookups → `low`). When the parameter is not exposed — note it, do not assume the parent's level carried over.

## Plan mode compatibility

In plan mode the harness restricts the available agents to Explore (Phase 1) and Plan (Phase 2). The routing above is compatible: Explore defaults to haiku; Plan defaults to opus. These orchestration rules apply after `ExitPlanMode`.

## Override mechanism

The user can explicitly cancel delegation: "do it yourself", "don't delegate", "write it by hand". In that mode the main session switches to hands-on until the end of the current task, then returns to orchestrator mode.

## Anti-patterns

- Running a grep over 200+ files from the main session (instead of Explore).
- An Edit in feature code from the main session (instead of kotlin-engineer / compose-developer).
- "Just one small Edit" in a production file from the main session — there is no such thing as a "small" production Edit; it all goes to a specialist.
- Running `./gradlew build` directly and waiting in the main context (instead of general-purpose in background).
- Passing a default `inherit` model to an agent without an explicit choice — the Haiku / Sonnet savings are lost.
- Delegating planning — the main session's synthesis power is wasted.
- Bypassing an existing skill in favor of a direct Agent.
- Skipping the STOP check before `Edit` / `Write` / `Grep` / `Glob` / a non-trivial `Bash` and jumping straight to the tool.
- Doing a review (security / performance / code review) inside the main session instead of with an expert agent.
- Подмена гейта `/finalize` разовым вызовом `code-reviewer`. `/finalize` — это полный review→fix→simplify loop; одиночное ревью оставляет его наполовину незавершённым (fix и simplify не выполнены). «Код уже отревьюен» гейт не закрывает.
- Сокращение profile-triggered reviewer panel. Если skill / профиль определяет panel правилами (`primary` + regex-matched `optional_if`) — использовать **весь** triggered set. «Эта область уже разобрана в прошлом ревью другого артефакта» — не основание для пропуска: research / spec / test-plan — разные тексты, разные failure modes, разные перспективы. Cost extra agent: 2-5 минут; cost пропуска: gap который вылезет после approval (свежий кейс — `desktop-v2-spec`: сократил panel 5→3, пропустил drag-positioning gap, который UX/perf ревьюер увидел бы сразу). Полный triggered set применять всегда, даже если кажется дублированием.
