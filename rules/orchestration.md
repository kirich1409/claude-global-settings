# Orchestration Rules

Main session = orchestrator on the most capable (expensive) model — its value is reasoning, planning, synthesis. Hands-on coding goes to cheaper Sonnet/Haiku specialists; keep the main session for decisions.

**May:** orientation research (Reads until focus drifts, targeted Bash, `git status`/`log`/`ls`/`pwd`, single-page MCP/web lookups like `mcp__plugin_context7_*` / `WebFetch`); edit process working files (state/report/debug/plan, `~/.claude/**`); plan synthesis from Explore/specialist summaries; final synthesis + the user-facing answer; Skill/Agent invocation with the right model.
**Must not:** edit project production code, do heavy multi-file code search, or wait on long-running build/test/CI in its own context.

### Process working files (main session edits directly)

| Category | Examples |
|---|---|
| State / reports / debug logs | `swarm-report/<slug>-{state,report,debug,e2e-scenario}.md` |
| Plan files in plan mode | files created in the current plan mode |
| Session notes | `MEMORY.md`, files in `memory/`, scratch files for the task |
| Global rules and configs | `~/.claude/CLAUDE.md`, `~/.claude/rules/**`, `~/.claude/settings*.json`, hooks |
| Process docs | READMEs/docs inside `~/.claude`, plugin tooling for agents |

These are **process** files, not project code — editing them is orchestration, not implementation.

## Forbidden (violation = error, see `CLAUDE.md § Non-negotiables`)

- Edit/Write in **project code** (production source, configs, tests) — delegate even one line.
- Heavy/multi-file grep / deep code search across the codebase → Explore (haiku). A targeted grep in 1–2 files for orientation is fine.
- Long-running build/test/CI in the main context → general-purpose in background.
- Review tasks (security/performance/UX/code review) → the matching expert agent.

**STOP before every `Edit`/`Write`/non-trivial `Grep`/`Glob`/`Bash`:** touching project code or mass file reads → subagent; a process file (table above) or `~/.claude/**` → fine; lightweight orientation (a few Reads, `git status`/`log`/`ls`, targeted routing grep) → fine. N edits in production code is one specialist job, not "many small ones from the main session."

## Skill-first

Task matches an installed skill → use the skill (it knows the right agent/model sequence). Direct Agent is the fallback when no skill fits. E.g. implementation → `/check` + `/finalize` + `/acceptance` + `/create-pr` + `/drive-to-merge`; new spec → `/write-spec`; UI migration → `/migrate-to-compose`; tests → `/write-tests`.

## Subagent code-search directive

Subagents do **not** inherit `~/.claude/rules/**` — they default to Grep/Read. When delegating any code search/read (Explore, general-purpose, specialists), include in the prompt:

> Use `ast-index` via Bash before Grep: `search "q"`, `file "Name"`, `class "Name"`, `usages "Name"`, `implementations "Name"`, `callers "fn"`. Grep only when ast-index is empty or for regex/string-literal search. Before `Read` on a file >~500 lines, run `ast-index outline <file>` and Read only the targeted slice via `offset`/`limit`. On "Index not found" → `ast-index rebuild`, never fall back to Grep.

(The index is kept fresh by hooks — see `rules/ast-index.md`; this only ensures the subagent *uses* it.)

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

For any PR/MR, issue, or Projects-board work (incl. delegated `gh`/`glab` calls): use the idempotent, timeout-safe toolkit in `$HOME/.claude/scripts/gh/` and follow `rules/github-ops.md` (mechanics) + `rules/github-merge-policy.md` (autonomy / anti-stall / per-project policy). Never block the main session on `gh run watch` / `gh pr checks --watch`.

## Model & effort

**Model (when not in the table):** `opus` — reasoning, planning, synthesis, multi-factor analysis, security/perf/UX/architecture review, debugging root cause; `sonnet` — implementation, refactor, code review, manual QA, build engineering, mid-complexity specialist tasks; `haiku` — search, lookups, admin CRUD, file discovery, mechanical transforms. Unclear between two adjacent models → pick the **smaller**, bump on first failure / poor result.

**Effort (`/effort`, main session only — subagents do not inherit it):** levels `low | medium | high | xhigh | max`. `xhigh`/`max` — planning, architecture, security review, debugging root cause, ambiguous trade-offs; `high`/`medium` — day-to-day orchestration/routing; `low` — narrow targeted edits, mechanical refactors, doc fixes, simple navigation (reasoning bumps amplify over-editing → on small fixes a lower level yields a cleaner diff, often faster). Persist via `~/.claude/settings.json: "effortLevel"` or env `CLAUDE_CODE_EFFORT_LEVEL` (env wins); `max` never persists across sessions. **Subagents:** always pass an explicit `model:`; where an effort param is exposed, pass it (planning/architecture → `xhigh`+; implementation/review → `medium`/`high`; mechanical lookups → `low`), else note it — never assume the parent's level carried over.

## Plan mode

Plan mode restricts agents to Explore (Phase 1, default haiku) and Plan (Phase 2, default opus) — compatible with the routing above. These rules apply after `ExitPlanMode`.

## Override

The user can cancel delegation ("do it yourself", "don't delegate", "write it by hand") → the main session goes hands-on until the current task ends, then returns to orchestrator mode.

## Anti-patterns (beyond the Forbidden list)

- Passing a default `inherit` model to an agent without an explicit choice — the Haiku/Sonnet savings are lost.
- Delegating planning — the main session's synthesis power is wasted.
- Подмена гейта `/finalize` разовым вызовом `code-reviewer`. `/finalize` — это полный review→fix→simplify loop; одиночное ревью оставляет его наполовину незавершённым (fix и simplify не выполнены). «Код уже отревьюен» гейт не закрывает.
- Сокращение profile-triggered reviewer panel. Если skill / профиль определяет panel правилами (`primary` + regex-matched `optional_if`) — использовать **весь** triggered set. «Эта область уже разобрана в прошлом ревью другого артефакта» — не основание для пропуска: research / spec / test-plan — разные тексты, разные failure modes, разные перспективы. Cost extra agent: 2-5 минут; cost пропуска: gap который вылезет после approval (свежий кейс — `desktop-v2-spec`: сократил panel 5→3, пропустил drag-positioning gap, который UX/perf ревьюер увидел бы сразу). Полный triggered set применять всегда, даже если кажется дублированием.
