# Recommended Workflow

The `developer-workflow` plugin family is a toolbox of on-demand skills, not a forced pipeline. Pick what the task needs; let plan mode drive sequencing.

## Mandatory gates

**Preparation gate — before any implementation.** Gather, autonomously and research-first, what's needed to build *and* verify — three outputs, actually collected, not just named:
- **Sources of truth** (what "done" means): spec/AC, before-state baseline, screenshots/Figma, debug-repro. Actively *produce* them — capture screenshots, boot the emulator, snapshot the baseline before a migration. What you can't make yourself and is missing → ask the user, naming what verification degrades without it. Detail: [[qa-and-testing]] §6 + [[task-types]] § Before-state baseline. Starting implementation without the sources of truth needed to verify it is not allowed.
- **Knowledge sources** (how to build it): trusted docs/source per tier T1–T4 — see [[external-sources]]. For non-trivial features, proactively seek reference code — stack samples (vendor-endorsed) + popular OSS in the same problem domain — not only API docs; see [[verify-library-api]] § Reference implementations. Agent memory and project code go stale; on a gap or doubt, verify against the official source, don't act from memory. Missing understanding or stuck → `research` skill first, not a question to the user.
- **Testability + decomposition**: assess how hard the change is to verify and propose simplifications up front (sample/sandbox app, screenshot tests, several emulators) so a prototype is exercised fast before touching the real app; decompose a task too large for one plan. Detail: [[task-types]] § Test feasibility gate.

Autonomy: concentrate questions in this prep phase; once sources are gathered, proceed without round-tripping. A standard/obvious solution — apply it, don't ask. Skip prep only for the same trivial cases as the gates below.

**Quality gate — `/finalize`.** Required after every implementation where code was written — before declaring the task done. Finalize owns *how the code is written*: it is a full review→fix→simplify loop that iterates until no findings above Minor severity remain, or exits with ESCALATE requiring a user decision. `code-reviewer` is one component the loop orchestrates — **a standalone run of code-reviewer does NOT close this gate**: review alone leaves the fix and simplify steps unperformed. «Код уже отревьюен» is not grounds to skip `/finalize`. Exceptions: pure documentation edits, config-only changes with no logic, single-line mechanical changes with an obvious result.

**Acceptance gate — `/acceptance`.** Runs after `/finalize` — before PR promotion. Verifies the implementation against the source of truth (spec, test plan, design, or behavioral baseline) and runs runtime checks including `manual-tester` for UI surfaces. The two gates are orthogonal: `/finalize` checks *how the code is written* (cleanliness), `/acceptance` checks *what the code does* (it works as intended) — neither replaces the other, both are mandatory. Same exceptions as `/finalize`.

**PR promotion gate — `/create-pr --promote`** (draft → ready for review) requires explicit user confirmation. Opening a draft PR is routine; promotion signals the task is complete and makes it visible to reviewers — that is a shared-state action.

## Flows

**Non-trivial features:**
1. Plan mode → **preparation gate** (above): gather + collect sources of truth (spec, Figma, AC list, before-state baseline for migrations), confirm knowledge sources, assess testability and decompose. Research-first for unknowns. Optional `/multiexpert-review` for high-risk plans, optional `/write-spec` when the change is too big to hold in head, `/write-plan` to commit a reviewable plan.
2. Implement on a feature branch in a worktree. Open draft PR early via `/create-pr --draft`.
3. `/check` → `/finalize` → `/acceptance` → `/create-pr --promote` (user confirmation required) → `/drive-to-merge`.

**Bug fixes:**
1. Plan mode (debug + fix in the plan). Capture reproduction steps in `swarm-report/<slug>-debug.md` — this is the source of truth for `/acceptance`.
2. Write a failing test that reproduces the bug first, then implement the fix (red-green) → `/check` → `/finalize` → `/acceptance` → PR. The regression test is not optional unless the feasibility gate applies — then a tracked exception, never a silent skip (see [[task-types]] bug-fix row + [[qa-and-testing]] §4). `/write-tests` can scaffold the test.

**Exploratory QA without a spec:** call the `manual-tester` agent directly via the Task tool (no skill needed).
