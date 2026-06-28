# Orchestration Rules

Main session = orchestrator on the most capable (expensive) model — its value is reasoning, planning, synthesis. Hands-on coding goes to specialists, dispatched at the right **model × effort**; keep the main session for decisions.

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

Task matches an installed skill → use the skill (it knows the right agent/model sequence). Direct Agent is the fallback when no skill fits. E.g. planning a decided change → `/write-plan`; implementation → `/check` + `/finalize` + `/acceptance` + `/create-pr` + `/drive-to-merge`; new spec → `/write-spec`; UI migration → `/migrate-to-compose`; tests → `/write-tests`.

## What subagents inherit (context delivery)

Verified empirically on current CC (general-purpose subagent): custom and built-in subagents **do** inherit the main session's `CLAUDE.md`, `MEMORY.md`, and every **unconditional** `~/.claude/rules/*.md` (those with no `paths:` frontmatter — including `ast-index.md`, `orchestration.md`, `external-sources.md`, `qa-and-testing.md`). They already carry the always-on rules — do **not** re-paste them into the delegation prompt.

Two gaps the subagent does **not** get automatically — restate these in the prompt only when they matter:
- **`paths:`-scoped rules** (`kotlin-style.md`, `gradle-style.md`, `android-cli.md`, `logging.md`, …) load lazily when a matching file is read — absent at subagent startup. If the subagent must honor such a rule before it touches a matching file, restate the key point or point it at the file path.
- **Explore and Plan** skip `CLAUDE.md` + rules entirely for speed (per CC docs — not separately verified here). For an Explore/Plan agent that must use ast-index, include the directive below.

**What to put in a delegation prompt** (the rest is inherited): the task; the relevant paths/modules; constraints (what not to touch, forbidden tools); the expected output shape; and any `paths:`-scoped rule or Explore/Plan-missing rule that applies.

**ast-index directive** (needed only for Explore/Plan, or an agent doing code search before its rule loads):

> Use `ast-index` via Bash before Grep: `search "q"`, `file "Name"`, `class "Name"`, `usages "Name"`, `implementations "Name"`, `callers "fn"`. Grep only when ast-index is empty or for regex/string-literal search. Before `Read` on a file >~500 lines, run `ast-index outline <file>` and Read only the targeted slice via `offset`/`limit`. On "Index not found" → `ast-index rebuild`, never fall back to Grep.

(Index kept fresh by hooks — see `rules/ast-index.md`.)

Model × effort dispatch and agent routing: see `model-effort-routing.md`.

## Plan mode

Plan mode restricts agents to Explore (Phase 1, default haiku) and Plan (Phase 2, default opus) — compatible with the routing above. These rules apply after `ExitPlanMode`.

## Override

The user can cancel delegation ("do it yourself", "don't delegate", "write it by hand") → the main session goes hands-on until the current task ends, then returns to orchestrator mode.

## Anti-patterns (beyond the Forbidden list)

- Leaving `model:` at default `inherit` without an explicit choice — the Haiku/Sonnet savings are lost.
- Delegating planning — the main session's synthesis power is wasted.
- Подмена гейта `/finalize` разовым вызовом `code-reviewer`. `/finalize` — это полный review→fix→simplify loop; одиночное ревью оставляет его наполовину незавершённым (fix и simplify не выполнены). «Код уже отревьюен» гейт не закрывает.
- Сокращение profile-triggered reviewer panel. Если skill / профиль определяет panel правилами (`primary` + regex-matched `optional_if`) — использовать **весь** triggered set. «Эта область уже разобрана в прошлом ревью другого артефакта» — не основание для пропуска: research / spec / test-plan — разные тексты, разные failure modes, разные перспективы. Cost extra agent: 2-5 минут; cost пропуска: gap который вылезет после approval (свежий кейс — `desktop-v2-spec`: сократил panel 5→3, пропустил drag-positioning gap, который UX/perf ревьюер увидел бы сразу). Полный triggered set применять всегда, даже если кажется дублированием.
