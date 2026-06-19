# Recommended Workflow

The `developer-workflow` plugin family is a toolbox of on-demand skills, not a forced pipeline. Pick what the task needs; let the `/plan` skill drive sequencing.

## Planning uses `/plan`, not built-in plan mode

Planning runs through the `developer-workflow:plan` skill (`/plan`) — **never** built-in plan mode. Built-in plan mode produces an *ephemeral* plan and a hard `ExitPlanMode` approval pause: it interrupts the session to ask for confirmation and cannot run inside a fully autonomous / headless agent. `/plan` removes both problems:

- It persists a reviewable plan under `docs/plans/<slug>/` (`plan.md` + `tasks.md` + `progress.md`) instead of an ephemeral prompt — version-controlled, resumable, referenced by `/create-pr` and `/finalize`.
- A mandatory adversarial multiexpert-review loop is the gate that **replaces** human approval, so there is no `ExitPlanMode` pause.
- It hands off to implementation autonomously by default. Opt into a single confirmation checkpoint with `/plan --interactive` when a human is present and wants one.

Reach for built-in plan mode only for throwaway, codebase-only scratch planning you do not intend to keep. The plan-stage dependency gate (`rules/dependencies.md`) and verification source-of-truth live inside the `/plan` document.

## Mandatory gates

**Quality gate — `/finalize`.** Required after every implementation where code was written — before declaring the task done. Finalize owns *how the code is written*: it is a full review→fix→simplify loop that iterates until no findings above Minor severity remain, or exits with ESCALATE requiring a user decision. `code-reviewer` is one component the loop orchestrates — **a standalone run of code-reviewer does NOT close this gate**: review alone leaves the fix and simplify steps unperformed. «Код уже отревьюен» is not grounds to skip `/finalize`. Exceptions: pure documentation edits, config-only changes with no logic, single-line mechanical changes with an obvious result.

**Acceptance gate — `/acceptance`.** Runs after `/finalize` — before PR promotion. Verifies the implementation against the source of truth (spec, test plan, design, or behavioral baseline) and runs runtime checks including `manual-tester` for UI surfaces. The two gates are orthogonal: `/finalize` checks *how the code is written* (cleanliness), `/acceptance` checks *what the code does* (it works as intended) — neither replaces the other, both are mandatory. Same exceptions as `/finalize`.

**PR promotion gate — `/create-pr --promote`** (draft → ready for review) requires explicit user confirmation. Opening a draft PR is routine; promotion signals the task is complete and makes it visible to reviewers — that is a shared-state action.

## Flows

**Non-trivial features:**
1. `/plan` → identify verification source of truth (spec, Figma, AC list, or behavioral baseline for migrations) → optional `/write-spec` first when the change is too big to hold in head (the plan then references the spec). `/plan` already runs its own mandatory multiexpert-review loop over the plan; reach for a standalone `/multiexpert-review` only outside that flow.
2. Implement on a feature branch in a worktree. Open draft PR early via `/create-pr --draft`.
3. `/check` → `/finalize` → `/acceptance` → `/create-pr --promote` (user confirmation required) → `/drive-to-merge`.

**Bug fixes:**
1. `/plan` (debug + fix in the plan). Capture reproduction steps in `swarm-report/<slug>-debug.md` — this is the source of truth for `/acceptance`.
2. Implement → optional `/write-tests` for regression → `/check` → `/finalize` → `/acceptance` → PR.

**Exploratory QA without a spec:** call the `manual-tester` agent directly via the Task tool (no skill needed).
