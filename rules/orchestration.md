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

Task matches an installed skill → use the skill (it knows the right agent/model sequence). Direct Agent is the fallback when no skill fits. E.g. implementation → `/check` + `/finalize` + `/acceptance` + `/create-pr` + `/drive-to-merge`; new spec → `/write-spec`; UI migration → `/migrate-to-compose`; tests → `/write-tests`.

## Subagent code-search directive

Subagents do **not** inherit `~/.claude/rules/**` — they default to Grep/Read. When delegating any code search/read (Explore, general-purpose, specialists), include in the prompt:

> Use `ast-index` via Bash before Grep: `search "q"`, `file "Name"`, `class "Name"`, `usages "Name"`, `implementations "Name"`, `callers "fn"`. Grep only when ast-index is empty or for regex/string-literal search. Before `Read` on a file >~500 lines, run `ast-index outline <file>` and Read only the targeted slice via `offset`/`limit`. On "Index not found" → `ast-index rebuild`, never fall back to Grep.

(The index is kept fresh by hooks — see `rules/ast-index.md`; this only ensures the subagent *uses* it.)

## Model & effort — two independent levers

Dispatch is a **(model × effort)** choice, not a model downgrade. Tune both to reach the result efficiently — running Opus everywhere at *lower* effort is a valid strategy when intelligence matters but cost/latency don't.

**Mechanics (what's actually settable):**
- **Model** — per call via the Agent tool's `model:` (`sonnet` / `opus` / `haiku` / `fable` / full id / `inherit`; default `inherit` = the main model). Set it explicitly — `inherit` silently keeps the expensive main model.
- **Effort** — `low | medium | high | xhigh | max`, but **only on Opus 4.x / Sonnet 4.6 / Fable; Haiku has no effort knob** (assigning effort to a Haiku agent errors). Effort is **not** a per-call Agent param — it comes from the agent definition's `effort:` frontmatter or the inherited session `/effort` (subagents inherit the session level as baseline; frontmatter overrides). For per-task effort control, pin `effort:` in the agent's frontmatter or use a Workflow (`agent({effort})`). `max` is session-only and never persists.

**Heuristic:**
- Mechanical / search / lookup / admin CRUD → **haiku** (no thinking; effort N/A).
- Substantive but bounded (implementation, refactor, code review, manual QA, build engineering) → **sonnet**, or **opus at low–medium**.
- Hard reasoning (planning, architecture, security/perf/UX review, debugging root cause, ambiguous trade-offs) → **opus at high–xhigh/max**.
- Unclear model between two adjacent tiers → pick the **smaller**, bump on first failure. Unclear effort → start **lower**, bump if the result comes back thin.

## Routing — choose from what's available

No fixed task→agent table. The harness already lists the agents available **in this project** with descriptions — match the task to the best-fit available agent by reading those, then apply the model/effort heuristic above. This stays correct as the available set changes per project (plugins enabled/disabled) instead of pointing at agents that aren't loaded.

**Non-obvious routing & guardrails** (won't be inferred from agent descriptions):
- **Planning / architecture / synthesis → keep in the main session** (or the `Plan` agent). Never delegate planning — it is the orchestrator's core value.
- Security / performance / UX / code review → the matching **expert agent**, never the main session.
- Code research / "find X / where is Y used" → **Explore** (haiku).
- Long-running build / test / CI → **general-purpose in the background**, never blocking the main session.
- Implementation in a stack → the stack specialist (Kotlin/Compose/Swift engineer) **when its plugin is available**; else general-purpose.
- Skill-first: if an installed skill covers the task, use it over a direct Agent.
- PR/MR, issue, or Projects-board work (incl. delegated `gh`/`glab`): the idempotent, timeout-safe toolkit in `$HOME/.claude/scripts/gh/` + `rules/github-ops.md` / `rules/github-merge-policy.md`. Never block on `gh run watch` / `gh pr checks --watch`.

## Plan mode

Plan mode restricts agents to Explore (Phase 1, default haiku) and Plan (Phase 2, default opus) — compatible with the routing above. These rules apply after `ExitPlanMode`.

## Override

The user can cancel delegation ("do it yourself", "don't delegate", "write it by hand") → the main session goes hands-on until the current task ends, then returns to orchestrator mode.

## Anti-patterns (beyond the Forbidden list)

- Leaving `model:` at default `inherit` without an explicit choice — the Haiku/Sonnet savings are lost.
- Delegating planning — the main session's synthesis power is wasted.
- Подмена гейта `/finalize` разовым вызовом `code-reviewer`. `/finalize` — это полный review→fix→simplify loop; одиночное ревью оставляет его наполовину незавершённым (fix и simplify не выполнены). «Код уже отревьюен» гейт не закрывает.
- Сокращение profile-triggered reviewer panel. Если skill / профиль определяет panel правилами (`primary` + regex-matched `optional_if`) — использовать **весь** triggered set. «Эта область уже разобрана в прошлом ревью другого артефакта» — не основание для пропуска: research / spec / test-plan — разные тексты, разные failure modes, разные перспективы. Cost extra agent: 2-5 минут; cost пропуска: gap который вылезет после approval (свежий кейс — `desktop-v2-spec`: сократил panel 5→3, пропустил drag-positioning gap, который UX/perf ревьюер увидел бы сразу). Полный triggered set применять всегда, даже если кажется дублированием.
