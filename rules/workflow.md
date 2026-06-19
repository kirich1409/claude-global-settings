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

Maximum autonomy at every stage: the per-artifact review loops replace human approval, so the pipeline runs end-to-end without confirmation pauses. The one deliberate exception is the PR promotion gate above. Every skill is on-demand — skip the ones a simple task doesn't need; the structure below is the *full* flow, not a mandatory minimum.

### Phase 1 — Sources of truth ("is this even worth building, and against what is it verified?")

1. `research` — when the approach / feasibility / options are undecided (skip for routine tasks where the *what* is already clear). New findings may send the loop back here.
2. `/write-spec` — turn an already-decided feature into an implementation contract (skip for simple tasks). Clarifications are gathered inline as it runs.
3. **Mandatory multi-review of the spec.** The spec is not a source of truth until a multiexpert panel has reviewed it. Clarifications surfaced in review are folded in inline; a serious gap may restart `research`.
4. `/generate-test-plan` — when the change needs structured executable cases → **mandatory multi-review of the test plan** before it becomes the acceptance contract.

The spec and the test plan are **permanent** sources of truth (`docs/specs/`, `docs/testplans/`) — they outlive the change.

### Phase 2 — Implementation

1. `/plan` — collect the implementation-level sources of truth, define which test-pyramid levels `/acceptance` must pass, and write clear per-task acceptance + test methods (skip for trivial changes). **The plan is mandatorily multi-reviewed before any implementation starts — an unreviewed plan must not be taken into work.** The plan lives in `docs/plans/<slug>/` in the repo throughout implementation and PR review, and is **transient scaffolding, not a permanent record**: `/drive-to-merge` removes it after the change merges (and it should not survive an abandoned/rejected change either).
2. Implement on a feature branch in a worktree. Open a draft PR early via `/create-pr --draft`.
3. `/check` → `/finalize`.

### Phase 3 — Verification

1. `/acceptance` — verify against the spec / test plan / behavioral baseline; run runtime checks including `manual-tester` for UI surfaces.
2. On failure: a **fix loop** (`/finalize` → `/acceptance` again), or — if the failure invalidates the approach itself — **roll all the way back to Phase 1** and revise the spec / plan. Do not patch around a broken contract.
3. `/create-pr --promote` (user confirmation required) → `/drive-to-merge` (merges, then removes the plan).

### Variants

**Bug fixes:** `/plan` captures debug + fix; reproduction steps go in `swarm-report/<slug>-debug.md` — the source of truth for `/acceptance`. Then implement → optional `/write-tests` for regression → `/check` → `/finalize` → `/acceptance` → PR.

**Exploratory QA without a spec:** call the `manual-tester` agent directly via the Task tool (no skill needed).
