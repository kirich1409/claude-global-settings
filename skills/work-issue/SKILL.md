---
name: work-issue
description: >
  Drive a single tracker issue end-to-end: fetch and triage the issue, gate on blockers,
  create a worktree, delegate implementation to a stack specialist, run the check→finalize→acceptance
  pipeline, push a draft PR linked to the issue, and move the board card.
  Triggers: "work issue #N", "take issue #N", "implement issue #N", "do issue #N",
  "возьми issue #N", "сделай задачу #N", "реализуй issue #N".
  Do NOT use for: creating/organizing/linking issues (project-coordinator agent),
  driving an existing PR to merge (drive-to-merge), or epics spanning multiple deliverables
  (decompose via project-coordinator first, then run this skill per sub-issue).
---

# Work Issue

Take one tracker issue from "open" to "draft PR + board card in In Progress". This is the
codification of the recurring per-issue microcycle (implement → review → fix → re-review →
push PR + board) so it runs as one skill invocation instead of a hand-driven agent chain.

Input: issue number `#N` (optionally repo when not the current one). Platform (GitHub/GitLab)
is detected from the remote per `rules/github-ops.md`; tracker mutations go through the
idempotent toolkit in `$HOME/.claude/scripts/gh/` — never raw `gh project` / manual GraphQL.

State file: `swarm-report/issue-<N>-state.md` (template per `rules/context-resilience.md`).
Create it in Phase 0, mark steps `[x]` only after verification, re-read before every
state-dependent action. Re-running the skill resumes from the first unchecked step —
tracker mutations are marker-idempotent, so a resume never double-posts.

## Phase 0 — Fetch & gate

1. `scripts/gh/fetch_issue.sh <N>` → title, body, labels, state. Closed issue → report, stop.
2. `scripts/gh/get_completion_signal.sh <N>` → merged PR already exists → report, stop;
   open PR exists → report it and ask whether to continue there instead (that PR may be the
   real work-in-progress; hand off to `drive-to-merge` if the user wants it landed).
3. `scripts/gh/get_dependencies.sh <N>` → any open blocker → STOP. Report the blocking
   issues; do not start implementation on top of unresolved dependencies.
4. Triage per `rules/workflow.md` Step 0:
   - Epic / multiple independent deliverables → stop; suggest decomposition
     (project-coordinator), then re-run this skill per sub-issue.
   - WHAT is not understood or contested → stop; route to `research` / `write-spec` first.
   - Fits in one PR and WHAT is decided → continue.
5. Classify the issue type (feature / bug / migration / refactor / infra) — this picks the
   verification source of truth and test discipline per `rules/task-types.md`.

## Phase 1 — Setup

1. `git fetch origin`; create worktree + branch off the default branch:
   `git worktree add -b <prefix>/<N>-<slug> .claude/worktrees/<N>-<slug> origin/<default>`.
   Prefix `feature/` | `fix/` | `chore/` by what the change does (`rules/git-workflow.md`).
2. Move the board card: `scripts/gh/transition_status.sh <N> in-progress`.
3. For bug issues: capture reproduction in `swarm-report/issue-<N>-debug.md` — it is the
   acceptance source of truth. For features: extract AC list from the issue body into the
   state file; if the issue has no usable AC, write the assumed AC down and flag them in the
   final report.

## Phase 2 — Implement

1. Non-trivial (multi-file, risky, several viable approaches) → produce a plan first
   (`write-plan`, or an inline plan in the state file for mid-size work). Trivial → skip.
2. Delegate implementation to the stack specialist (kotlin-engineer / compose-developer /
   swift-engineer / swiftui-developer / general-purpose) with model × effort per
   `rules/model-effort-routing.md`. The brief includes: issue title + body, AC list,
   worktree path, constraints, and expected output shape. The main session never edits
   product code itself.
3. Bug issues: red-green — failing test reproducing the bug first, watch it fail, then fix
   (`rules/task-types.md`).

## Phase 3 — Verify & polish

Run the standard gates in order; none is optional for code changes (exceptions per their
own rules: docs-only, config-only, one-line mechanical):

1. `/check` — build, lint, tests green.
2. `/finalize` — full review→fix→simplify loop (a single code-reviewer pass does not
   close this gate).
3. `/acceptance` — verify against the source of truth from Phase 0/1 (AC list, debug repro,
   or behavioral baseline).

## Phase 4 — Ship & report

1. Commit(s) per `rules/git-workflow.md`; push the branch.
2. `/create-pr --draft` — the PR body references the issue with `Closes #N` (GitHub) /
   `Closes #N` (GitLab) so merge auto-closes it.
3. `scripts/gh/link_pr.sh <N> <PR>` — marker-idempotent link comment on the issue.
4. Board card stays **In Progress** — it moves to In Review only on `--promote`
   (state machine in `rules/github-ops.md`).
5. Report: issue, branch, PR link, verification receipts (check/finalize/acceptance),
   assumed-AC flags if any, and the two explicit handoffs:
   - promotion to ready-for-review = `/create-pr --promote` (needs user confirmation);
   - landing the PR = `/drive-to-merge` (separate skill; this one stops at draft).
6. Delete the state file only after the PR is promoted or the user closes the task;
   until then it is the resume point.
