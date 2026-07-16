---
name: implement-plan
description: "Execute an approved implementation plan task-by-task — the delivery counterpart to write-plan. Consumes docs/plans/<slug>/{plan,tasks,progress}.md, builds the execution DAG from the tasks' `after:` dependencies, chooses an execution strategy (sequential, or auto-parallel across independent DAG layers with worktree isolation), seeds a live TodoWrite status list rendered in the Claude Code interface, and dispatches a specialist subagent per task — the main session orchestrates, specialists write the code. Each task is gated by its own `check` before it is marked done; progress.md is the durable ledger, TodoWrite the live view. Use when: \"implement the plan\", \"execute the plan\", \"build out docs/plans/<slug>\", \"start the tasks\", \"run the plan\", \"do the implementation\" for an ALREADY-WRITTEN, approved plan. Do NOT use for: writing the plan (use write-plan), deciding what/how (use research / write-spec), code from scratch with no plan (write a plan first), or getting an open PR merged (use drive-to-merge)."
---

# Implement Plan

Turn an **approved, on-disk plan** into shipped code, task-by-task, safely and autonomously. This is
the delivery counterpart to `write-plan`: that skill produces `docs/plans/<slug>/{plan,tasks,progress}.md`;
this skill executes them.

**Role:** Delivery orchestrator. The plan is the contract; this skill walks its tasks in dependency
order, dispatches a specialist to implement each one, verifies each against its own `check`, and keeps
both the live status list and the durable ledger truthful.

**Hard boundary (orchestration.md):** the main session **never edits production code** — it delegates
every code edit, even a one-liner, to a subagent. So this skill is an *orchestrator*: it reads,
decides, dispatches, and integrates; the implementer subagents write files and run the per-task
`check`. Heavy builds/tests run inside the subagent's context, not the main session's.

**Core principles:**

1. **Orchestrate, don't implement.** Every task's code is written by a dispatched specialist at the
   right `model × effort` ([[model-effort-routing]]), never by the main session.
2. **Two-level status.** `TodoWrite` is the live in-session view rendered in the Claude Code
   interface; `progress.md` is the durable committed ledger that survives compaction and resume
   ([[context-resilience]]). A task is done only when both agree.
3. **Every task is gated by its own `check`.** A task is `completed` only after the specialist runs
   the `check` from `tasks.md` and it passes — never on "looks done".
4. **Strategy is chosen from the plan, at launch.** The `after:` dependency graph and per-task risk
   decide sequential vs. parallel; the choice is stated up front, not hard-coded.

### Headless mode (the autonomy contract)

Default is autonomous: no approval pauses. `AskUserQuestion` is used **only** with `--interactive`
or when a user is actively present. In a headless run, never block on it — on a genuine blocker
(a task's `check` fails after one retry, the plan contradicts the codebase, a parallel conflict
can't be resolved) STOP per [[task-execution]] and surface the blocker, leaving `progress.md` truthful
so a later `--resume` picks up exactly where it stopped.

---

## Flags

| Flag | Effect |
|---|---|
| (default) | Autonomous. Load plan → build DAG → auto-select strategy → seed TodoWrite → execute all tasks → whole-change verification → hand off. |
| `--interactive` | Present the chosen strategy + task order for one go/adjust confirmation before executing, and pause before any task tagged risky. |
| `--sequential` | Force strict one-at-a-time order; never parallelize (the safe default when in doubt). |
| `--parallel` | Permit fan-out of independent DAG layers with worktree isolation (see reference). Auto-selection may pick this anyway; the flag forces it where safe. |
| `--resume` | Continue an interrupted run: pre-mark `progress.md` `[x]` tasks done and start at the first unchecked task. |
| `--dry-run` | Print the resolved DAG, the chosen strategy, and the per-task dispatch plan — dispatch nothing. The "think through the options at launch" preview. |
| `--from <slug\|path>` | Target a specific plan instead of auto-discovering one. |

---

## Phase 0: Load & Validate

Resolve the plan directory `docs/plans/<slug>/` (from `--from`, else the branch/task-derived slug,
else the newest plan whose slug matches the task). Read `plan.md`, `tasks.md`, `progress.md`.

STOP and redirect if:

- **No plan exists** → redirect to `write-plan`; this skill executes a plan, it does not invent one.
- **`plan.md` `status` is not `approved`** (still `draft`, or `review_verdict: escalate`) → the plan
  has not passed its review gate; surface the open questions and stop.
- **`tasks.md` has a task with no checkable `check`** → an unverifiable task cannot be safely
  auto-executed; flag it and stop (or, `--interactive`, ask how to verify it).

Read the plan's **Verification & Sources** section now — it defines the whole-change gate for Phase 4,
and for a migration / "shouldn't change behavior" task it names a before-state baseline that must be
captured **before** the first edit ([[qa-and-testing]], [[task-types]]).

---

## Phase 1: Build the DAG & Choose Strategy

Parse each task's `after:` field into a dependency graph and derive its topological **layers** (a
layer = tasks whose dependencies are all satisfied). Then choose how to walk it — the details
(layering, the file-disjointness + risk test for parallelism, worktree isolation, fall-back rules)
live in [`references/strategy-selection.md`](references/strategy-selection.md).

- **Default auto-selection:** sequential, *unless* a layer holds ≥2 tasks that touch **disjoint**
  files and carry no shared risk — then that layer may fan out in parallel, each task in its own
  worktree (`.worktrees/`, [[git-workflow]]), integrated back one at a time. When unsure, sequential
  wins: parallelism is an optimization, never a correctness requirement.
- `--sequential` / `--parallel` override the auto-choice; `--dry-run` prints it and stops.
- State the resolved strategy in one line before executing (e.g. *"9 tasks, 4 layers; layer 2
  (T-3,T-4) parallel — disjoint files; rest sequential"*). With `--interactive`, get one go/adjust
  confirmation here.

---

## Phase 2: Seed Live Status

Seed a `TodoWrite` list with one item per `T-N` from `tasks.md`, in DAG order, all `pending`. This is
the live view in the Claude Code interface. With `--resume`, mark tasks already `[x]` in `progress.md`
as `completed` and begin at the first unchecked one. Keep exactly one task `in_progress` at a time
(one per parallel branch when fanning out).

---

## Phase 3: Execute Loop

For each task, honoring the chosen strategy:

1. **Mark `in_progress`** in TodoWrite.
2. **Dispatch a specialist subagent** ([[model-effort-routing]] for `model × effort`; a `paths:`-scoped
   style rule for the task's files — `kotlin-style`, `swiftui-*`, etc. — is passed in the prompt since
   subagents don't load it until they touch the file, per [[orchestration]]). The dispatch brief carries:
   the task block verbatim (title, `files`, `acceptance`, `check`), the relevant slice of `plan.md`
   (approach, decisions, constraints), the **minimal-diff** mandate (touch only what the task requires
   — CLAUDE.md Principles), and the instruction to **run the `check` itself** and return a structured
   pass/fail verdict with evidence (test output, build target, grep result). A parallel layer dispatches
   its siblings concurrently, each in its own worktree.
3. **On the `check` passing:** mark the TodoWrite item `completed`, check the task's box in
   `progress.md`, and append one learning line (surprises, gotchas, decisions taken). For a parallel
   layer, integrate each passing worktree back into the working branch one at a time; a merge conflict
   demotes the remaining siblings to sequential.
4. **On failure / blocked:** per [[task-execution]] — diagnose, one autonomous retry (re-dispatch with
   the failure evidence), then STOP and surface if still failing. Never mark a task done on a failing
   or unrun `check`. `progress.md` stays truthful so `--resume` restarts exactly here.

The main session only **reads** each subagent's verdict — it does not run the builds/tests itself.

---

## Phase 4: Whole-Change Verification

Per-task checks prove each task; they do not prove the whole change is coherent. After the last task,
run the plan's **Verification & Sources** contract — the pyramid levels L0–L5 it declares
([[qa-and-testing]]). Delegate this (invoke `/check`, or a verifier/general-purpose subagent in the
background for a long build) — never run it in the main session. L5 (working-app) is mandatory for
library bumps, migrations, and infra-layer changes; if the plan marked a mandatory level and it's
skipped, name it and the tracked exception rather than passing silently.

---

## Phase 5: Hand Off

Retire any operational state file. Confirm completion in one sentence (plan path, tasks done, the
verification verdict). Then suggest the toolbox next steps — do **not** auto-chain them:
`/write-tests` (if coverage gaps remain) → `/finalize` (code-quality pass) → `/acceptance`
(working-app proof) → `/create-pr` → `/drive-to-merge`. The implementer commits plan + code together
so the PR shows the plan that produced the change.

---

## Red Flags / STOP Conditions

- **No plan / unapproved plan** — nothing to execute safely. Redirect to `write-plan`; do not
  improvise tasks.
- **Unverifiable task** — a `check` that isn't a concrete test/grep/build target. Auto-execution is
  only safe when "done" is checkable; flag and stop.
- **Plan contradicts the codebase** — a task's `files`/approach no longer match reality (the plan
  drifted). Stop, report the drift, and update the plan — do not silently improvise around it
  ([[task-execution]] scope creep).
- **Parallel tasks collide** — tasks in a "parallel" layer turn out to share files or state. Fall
  back to sequential for that layer; never race two writers on the same file.
- **Missing critical access** — a task needs systems / APIs / credentials not available. List what's
  needed and stop.
