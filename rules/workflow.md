# Recommended Workflow

The `developer-workflow` plugin family is a toolbox of on-demand skills, not a forced pipeline. Pick what the task needs; let plan mode drive sequencing.

## Mandatory gates

**Quality gate — `/finalize`.** Required after every implementation where code was written — before declaring the task done. Finalize owns *how the code is written*: it is a full review→fix→simplify loop that iterates until no findings above Minor severity remain, or exits with ESCALATE requiring a user decision. `code-reviewer` is one component the loop orchestrates — **a standalone run of code-reviewer does NOT close this gate**: review alone leaves the fix and simplify steps unperformed. «Код уже отревьюен» is not grounds to skip `/finalize`. Exceptions: pure documentation edits, config-only changes with no logic, single-line mechanical changes with an obvious result.

**Acceptance gate — `/acceptance`.** Runs after `/finalize` — before PR promotion. Verifies the implementation against the source of truth (spec, test plan, design, or behavioral baseline) and runs runtime checks including `manual-tester` for UI surfaces. The two gates are orthogonal: `/finalize` checks *how the code is written* (cleanliness), `/acceptance` checks *what the code does* (it works as intended) — neither replaces the other, both are mandatory. Same exceptions as `/finalize`.

**PR promotion gate — `/create-pr --promote`** (draft → ready for review) requires explicit user confirmation. Opening a draft PR is routine; promotion signals the task is complete and makes it visible to reviewers — that is a shared-state action.

## Flows

**Non-trivial features:**
1. Plan mode → identify verification source of truth (spec, Figma, AC list, or behavioral baseline for migrations) → optional `/multiexpert-review` for high-risk plans, optional `/write-spec` when the change is too big to hold in head.
2. Implement on a feature branch in a worktree. Open draft PR early via `/create-pr --draft`.
3. `/check` → `/finalize` → `/acceptance` → `/create-pr --promote` (user confirmation required) → `/drive-to-merge`.

**Bug fixes:**
1. Plan mode (debug + fix in the plan). Capture reproduction steps in `swarm-report/<slug>-debug.md` — this is the source of truth for `/acceptance`.
2. Implement → optional `/write-tests` for regression → `/check` → `/finalize` → `/acceptance` → PR.

**Exploratory QA without a spec:** call the `manual-tester` agent directly via the Task tool (no skill needed).
