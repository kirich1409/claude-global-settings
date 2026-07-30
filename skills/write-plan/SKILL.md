---
name: write-plan
argument-hint: "[--test-plan | --no-test-plan] [--interactive] [--quick] [--from-spec path]"
description: "Produce a committed implementation plan document — the autonomous replacement for built-in plan mode. Investigates the codebase read-only, writes a persistent, reviewable plan (docs/plans/<slug>/plan.md + tasks.md) instead of an ephemeral approval prompt, optionally adds a structured test plan under docs/testplans/, then runs a MANDATORY multiexpert-review loop and revises until it passes. No human approval pause by default, so an agent can plan and execute end-to-end; opt into a checkpoint with --interactive. Use when: \"plan this\", \"make a plan\", \"how do I build this\", \"plan the implementation\", \"break this into tasks\", \"plan before coding\" for an ALREADY-DECIDED change — and for test-plan requests, which are now a phase of this skill: \"write a test plan\", \"write test cases\", \"what should I test\", \"what are the edge cases\", \"plan testing coverage\". Prefer this over built-in plan mode whenever the plan should be saved, reviewed by experts, or executed autonomously. Do NOT use for: deciding WHAT to build or comparing options (use research), writing the feature contract / acceptance criteria (use write-spec), running tests against a live app (use /acceptance), or trivial single-line edits (just do them)."
---

# Plan

Turn an already-decided change into a **persistent, expert-reviewed implementation plan** that an
agent can execute end-to-end without stopping for approval. This is the autonomous replacement for
built-in plan mode: the plan is a file on disk (not an ephemeral `ExitPlanMode` prompt), so it can
be version-controlled, reviewed by a multiexpert panel, referenced by `create-pr` and
`/acceptance`, and resumed across sessions.

**Role:** Tech Lead translating *what* into *how*. The decision is made (by the user, a spec, or
prior research); this skill produces the technical approach, the ordered task list, and the
per-task acceptance that makes autonomous execution safe.

**Where it sits:** `write-spec` answers *what* we build (requirements + acceptance criteria). `plan`
answers *how* (design + ordered tasks). If a spec exists, the plan **references** it and never
duplicates its requirements. If no spec exists (smaller change), the plan works directly from the
task description.

**Core principles:**

1. **The plan is a document, not a prompt.** Persist it before anything else needs it. Ephemeral
   plans cannot be reviewed, diffed, or resumed — that is the limitation this skill removes.
2. **Review replaces approval.** The quality gate is a mandatory multiexpert-review loop, not a
   human pause. The default flow is autonomous; a human checkpoint is opt-in (`--interactive`).
3. **Every task has a verifiable done-condition.** Tasks carry explicit acceptance (Given/When/Then
   or "THE SYSTEM SHALL …"). Autonomy is only safe when "done" is checkable, not approved.

### Headless mode (the autonomy contract)

`AskUserQuestion` is used **only** when `--interactive` was passed or a user is actively present.
In a headless / non-interactive run, never block on it: surface a genuine design fork to the caller
instead. Before the plan file exists (Phase 1), surface it as a blocking hand-off; after the plan
exists, record it as a `[blocking]` Open Question, set `review_verdict: escalate`, and stop. This
single rule governs every later phase — phases below reference it rather than restating it.

---

## Flags

| Flag | Effect |
|---|---|
| (default) | Autonomous. Investigate → write plan → mandatory review loop → on PASS/CONDITIONAL, hand off to implementation with no human pause. |
| `--interactive` | Add ONE human confirmation checkpoint after the review passes (Phase 4.2). The explicit, opt-in replacement for the `ExitPlanMode` gate. |
| `--quick` | Trivial, well-bounded change: lighter investigation, single-reviewer review (`allow_single_reviewer`). Review is never skipped entirely — a plan without review is the failure mode this skill exists to prevent. |
| `--from-spec <path>` | Anchor the plan to a specific spec instead of auto-discovering one. |
| `--test-plan` / `--no-test-plan` | Force or suppress Phase 2.5. Neither given → the agent decides by the criteria in that phase and states which way it went. |

---

## Phase 0: Parse Input & Setup

### 0.1 Separate decision from design

The *what* is assumed decided. Extract:

- **The decided change** — what we are building (from the request, a spec, or research).
- **Source of truth** — auto-discover a spec: newest `docs/specs/*-<slug>.md` whose slug or title
  matches the candidate slug. If `--from-spec <path>` was passed, use that path directly and skip
  auto-discovery (verify the path exists; if not, stop and report). Record the path; the plan
  references it, never restates its AC. The slug is always the branch/task-derived candidate — do
  not parse a slug out of the `--from-spec` filename.
- **Known constraints** — platform, libraries, "no new deps", deadlines.

If the request is actually *undecided* ("should we use X or Y?", "is this feasible?"), STOP and
redirect to `research`. If it is a feature contract that has not been written ("what exactly are the
requirements?"), redirect to `write-spec`. This skill plans execution; it does not decide scope.

Generate a kebab-case slug (`offline-mode`, `push-notifications`). Strip common branch prefixes
(`feature/`, `fix/`, `chore/`, `claude/`, `hotfix/`). This candidate slug is used consistently
for all output paths (`docs/plans/<slug>/`). If a spec exists under `docs/specs/` whose slug or
title matches the candidate slug, reference it — but do not change the slug; plan, create-pr, and
acceptance all resolve the same `docs/plans/<slug>/` path.

### 0.2 Artifacts

Three committed files under `docs/plans/<slug>/` (`plan.md`, `tasks.md`, `progress.md`), plus
`docs/testplans/<slug>-test-plan.md` and its receipt when Phase 2.5 runs, plus the
gitignored operational `./swarm-report/plan-<slug>-state.md` (deleted after). `docs/plans/` is
deliberately alongside `docs/specs/` (spec = *what*, plan = *how*); plans live in git because their
value is being reviewable in the PR and resumable later. See
[`references/output-layout.md`](references/output-layout.md) for the full file/lifetime/purpose
table.

---

## Phase 1: Investigate (read-only)

Like plan mode, planning starts with read-only investigation — but the findings are persisted, not
discarded. Launch investigation **in a single message** (parallel) sized to the change:

- **Codebase (Explore)** — always. Existing code, patterns, module boundaries, the exact files and
  symbols this change touches, test infrastructure, related TODOs.
- **Architecture Expert** — when the change adds a module, shifts dependency direction, introduces
  an abstraction, or crosses layers.
- **Web / docs** — only for unfamiliar external APIs, protocols, or non-trivial algorithms the
  codebase doesn't already demonstrate.

Write findings into `./swarm-report/plan-<slug>-state.md` as agents complete. Do not ask the user
anything that investigation can answer. If a genuine design fork appears that investigation cannot
resolve, surface it with `AskUserQuestion` (each option with a recommended pick) — never park
questions in the plan file. The plan file does not exist yet at this phase, so per the **Headless
mode** contract above, a headless run surfaces the blocking fork to the caller (nothing to record
in-file).

`--quick`: skip the consortium; one inline Explore pass is enough.

---

## Phase 2: Write the Plan

Write `plan.md` and `tasks.md` for a reader who is an implementing agent with zero extra context.
Every decision is explicit with rationale; every task has a checkable done-condition.

Copy the templates from [`references/plan-template.md`](references/plan-template.md) verbatim and
fill every placeholder. Shape:

- **`plan.md`** — YAML frontmatter (`type: plan`, `slug`, `date`, `status: draft`, `spec:` link or
  `none`, `risk_areas`, `review_verdict: pending`) + body: Context & Decision, Technical Approach,
  Affected Modules & Files (table: path · change type · note), Decisions Made (with rationale),
  Risks & Mitigations, **Verification & Sources**, Out of Scope, Open Questions (tagged blocking /
  non-blocking). The **Verification & Sources** section is mandatory and must name the source(s) of
  truth that define "done" (spec / test-plan / before-state baseline / Figma / debug-repro),
  assert each is collected and **sufficient** to verify the finished change, and state the testing
  strategy (pyramid levels L0–L5 that apply). For a migration or "shouldn't change behavior" task the
  baseline is captured **before** implementation, not promised — a plan that only names a source
  without confirming it exists and suffices is not done (qa-and-testing §6, §0; task-types
  § Before-state baseline).
- **`tasks.md`** — ordered list `T-N`, each with: short title, dependencies (`after: T-…`), the
  files it touches, an **`interface:`** contract (`consumes` / `produces` — the exact symbols/signatures
  this task takes from earlier tasks and exposes to later ones, so a subagent seeing only its own task
  knows its neighbours' API and independent tasks can run in parallel without drift), and **acceptance**
  in Given/When/Then or "THE SYSTEM SHALL …" form, plus the check that proves it (test name, grep,
  build target). Tasks are small enough to implement and verify in one focused pass.
- **`progress.md`** — initialize with every `T-N` as an unchecked box and an empty Learnings log.

The plan must reference, not restate, the spec's acceptance criteria (cite `AC-N` ids); `tasks.md`
acceptance is the *implementation-level* check that each AC is met.

---

## Phase 2.5: Optional test plan

A test plan is a separate artifact from the implementation plan: `plan.md` says how the change is
built, the test plan enumerates the executable cases that prove it behaves. It belongs here
because the two are decided together — a test plan written apart from the plan it verifies drifts
from it immediately.

**Whether to write one.** `--test-plan` and `--no-test-plan` decide it outright. Otherwise judge
it, and say which way you went and why in the hand-off:

- **Write it** when the change has a UI surface; when the spec carries `acceptance_criteria_ids`
  that need case-level mapping; when the device block (L3–L5) will run and `manual-tester` needs a
  scenario to execute; when the feature has phases or enough branches that per-task acceptance
  cannot enumerate them.
- **Skip it** when `tasks.md` acceptance already is the executable case list — a narrow non-UI
  change, a refactor with behavior held 1:1, a single-module fix. Duplicating those rows into a
  second document only creates two places to update.
- **Bug fix** — skip. The reproduction in `swarm-report/<slug>-debug.md` is the case, and the
  regression test is written before the fix ([[task-types]]).

**How to write one:** method, slug rule, format variants, field definitions, and the receipt
schema live in [`references/test-plan.md`](references/test-plan.md) with its two companions
([`test-plan-templates.md`](references/test-plan-templates.md),
[`test-plan-receipt.md`](references/test-plan-receipt.md)). Output is
`docs/testplans/<slug>-test-plan.md` plus the receipt at `swarm-report/<slug>-test-plan.md`,
under **the plan's slug** — a divergent slug silently breaks the `/acceptance` mount.

The plan's **Verification & Sources** section then names the test plan as a source of truth, and
Phase 3 reviews both artifacts: the `test-plan` profile of `multiexpert-review` applies to the
test plan, the `implementation-plan` profile to the plan.

---

## Phase 3: Mandatory Review Loop

The review is the gate that replaces human approval. It is **not optional** (this is the whole
point — an unreviewed plan is low quality and must be sent back for rework until it meets the bar).

**Writer vs. skeptic.** The agent that wrote the plan (Phase 2) has an incentive to pass the gate
quickly; the critic is deliberately separate and adversarial. The reviewers act as a strict-but-fair
red team applying an anti-gaming rubric (reject hand-waving, demand `file:line` evidence, demand
checkable acceptance, hunt missing failure modes) — they look for what is *wrong*, not for reasons
to approve. See [`references/review-loop.md`](references/review-loop.md) for the writer/critic
rationale and the rubric.

This mirrors `write-spec` Phase 4.3: invoke `multiexpert-review` **inline** with an explicit profile
hint. The plan is already a file (`docs/plans/<slug>/plan.md`), so the engine classifies the source
as `file` and edits the plan in place on FAIL/CONDITIONAL.

Prepend to the review args:

```
profile: implementation-plan
---
docs/plans/<slug>/plan.md
```

(Why the hint and the full loop script: see
[`references/review-loop.md`](references/review-loop.md).)

The `implementation-plan` profile selects 2–3 reviewers by tech-match from the plan content
(e.g. `security-expert` only when the plan touches auth / tokens / user data; `architecture-expert`
only on new modules / dependency-direction / public-API changes). `--quick` permits a single
reviewer.

**Loop:** run the review loop — the cap and per-verdict actions live in
[`references/review-loop.md`](references/review-loop.md). PASS → proceed to Phase 4;
CONDITIONAL/FAIL → the engine edits the plan and re-reviews until the cap.

**Escalation (the only autonomous STOP):** if blockers remain after the cap, set `review_verdict: escalate`, write
the unresolved blockers into `## Open Questions` (tagged blocking), retire the state file (see Phase
4.3), and surface them — only for genuine blockers, never for routine polish.

---

## Phase 3.5: Adversarial Red-Team Pass

Reviewers grade against a rubric; an *implementer* discovers missing pieces — different failure
modes. After the panel passes, run **one** Agent (general-purpose, sonnet) as a hostile implementer
that tries to build from the plan and reports every gap it would hit; feeding findings back is
subject to the **Headless mode** contract above. The full agent brief and per-item handling live in
[`references/review-loop.md`](references/review-loop.md) §Phase 3.5.

Skip only with `--quick` on a small, well-bounded change with no risky tasks.

---

## Phase 4: Gate

### 4.1 Default — autonomous

On PASS/CONDITIONAL, flip `plan.md` `status` to `approved`, ensure `tasks.md` and `progress.md` are
written, retire the state file, and hand off to implementation **without pausing**. Confirm in one
sentence with the plan path and the first task. This is full autonomy: no `ExitPlanMode`, no
approval prompt.

### 4.2 `--interactive` — opt-in checkpoint

Only when `--interactive` was passed: present a compact summary (plan path, the 3–5 key decisions,
the task count, the review verdict, any non-blocking open questions) and ask for a single go / adjust
confirmation before flipping to `approved`. This is the deliberate, user-requested replacement for
the plan-mode approval gate — present only, never the default.

### 4.3 Escalate

On `review_verdict: escalate`, do not flip to `approved`. Retire (delete) the state file
`./swarm-report/plan-<slug>-state.md`, surface the blocking open questions, and stop — exactly as
`/acceptance` escalates on unresolved BLOCKs.

---

## Phase 5: Hand Off

This skill **authors** the plan; it does not execute it. Initialize `progress.md` with one unchecked
box per `T-N` and an empty learnings log — the durable execution ledger the executor updates as work
lands. Then suggest the next step: `/implement-plan` to execute the plan task-by-task (it seeds the
live `TodoWrite` status list and drives the `tasks.md` DAG via specialist subagents), then
`/acceptance`.

See [`references/output-layout.md`](references/output-layout.md) for path conventions, the
confirmation message, gitignore notes, and the hand-off rules (do-not-auto-invoke, the toolbox model,
and the Phase 3 / Phase 3.5 built-in exceptions).

---

## Red Flags / STOP Conditions

- **Undecided scope** — the request is "which approach?" or "is this feasible?". Redirect to
  `research`; do not plan an undecided change.
- **Missing contract** — a complex feature with no acceptance criteria anywhere. Recommend
  `write-spec` first; a plan without a target is guesswork.
- **Fundamental contradiction** — a constraint makes the change impossible, or two decided
  requirements conflict. Surface it; do not invent a workaround.
- **Missing critical access** — the change needs systems / APIs / credentials not available. List
  what's needed and stop.
