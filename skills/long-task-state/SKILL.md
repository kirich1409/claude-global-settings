---
name: long-task-state
description: >-
  Keep a long, multi-step task recoverable across context compaction, agent handoff, and
  session restarts by holding state in files rather than in the conversation. Covers the
  canonical state / e2e-scenario / debug / report files in swarm-report/, their templates,
  the re-read-before-acting rule, and how a durable checklist pairs with a live TodoWrite list.

  Use when: starting a task that will span many steps or sessions, executing a written plan,
  a multi-step refactor or batch fix, an investigation whose findings must survive compaction,
  "save progress", "where did we leave off", resuming after a compact, or writing a final
  task report.

  Do NOT use for: work that finishes in a handful of tool calls, or authoring a plan
  document (use write-plan).
---

# Long-task state

For long multi-step work, hold state in a file so it survives context compaction. Three
canonical files live in `./swarm-report/` (which belongs in `.gitignore`).

| File | Purpose | Lifetime |
|---|---|---|
| `<slug>-state.md` | Operational checklist for any long task — executing a plan, a multi-step refactor, a batch fix | Delete when the task is done |
| `<slug>-e2e-scenario.md` | Verification scenario against the running app; the single source of truth for "verified". Managed by `acceptance` when invoked | Survives acceptance restarts |
| `<slug>-debug.md` | Bug investigation: reproduction steps, observed vs expected, hypotheses, root cause. Picked up by `acceptance` and by `create-pr` for the bug-fix PR body | Stays as an audit trail |

A fourth file, `<slug>-report.md`, is the final report — see below.

## Templates

`<slug>-state.md`:

```markdown
# State: <slug>
Goal: <one sentence>

## Steps
- [x] 1. <done step> → verify: <check that proved it> ✅
- [ ] 2. <next step> → verify: <check that will prove it>
- [ ] 3. ...
```

Every step carries `→ verify: <check>` — the concrete signal that proves the step is done.
Turn vague requests into checks immediately: "add validation" → "test for invalid input
passes"; "fix the bug" → "the regression test reproducing it now passes".

`<slug>-e2e-scenario.md`:

```markdown
# E2E Scenario: <task name>
Type: Feature / Bug fix
Platforms: Android / iOS / Web / Backend / Desktop  (one or several)

## Steps
- [ ] 1. Open screen X
- [ ] 2. Tap button Y → expect state Z
- [ ] 3. ...
```

`<slug>-debug.md`:

```markdown
# Debug: <bug slug>
Status: Investigating | Root cause found | Fixed
Platform: <platform>

## Reproduction
1. ...
2. → expected: X, actual: Y

## Stacktrace / logs
...

## Hypotheses
- ...

## Root cause
<file:line + one-paragraph explanation>

## Fix outline
<files to touch, approach>
```

## Re-read before acting

Before any action that depends on prior state, read the file first. Completed steps (`[x]`)
are not redone; resume from the first `[ ]`. Mark `[x]` only after the action is verified,
never speculatively. When a step is rolled back, edit the file: the file is the truth, the
chat is not.

On `/compact` or at session end, the active state files are the recovery point: current goal,
open TODOs, verification commands, key architectural decisions all live there.

## Live status in the UI (TodoWrite)

The durable file survives compaction but does not show live status in the UI while work is in
flight. When **executing** a multi-step task (including running a plan's
`docs/plans/<slug>/tasks.md`), keep a parallel `TodoWrite` list as a live projection: one item
per step or `T-N`, exactly one `in_progress`, flipped to `completed` as soon as the step is
verified — not speculatively, same as `[x]` in the file.

Division of roles: the **durable file is the source of truth** (it survives `/compact`, an
agent switch, a resume — it is the recovery point), while **TodoWrite is an ephemeral live
projection** (it dies with compaction or session end). So the list is re-seeded from the file
on resume, not the other way round. A step is done only when both agree: the TodoWrite item is
`completed` **and** the box in the file is `[x]`.

This is a rule about execution — it does not apply to authoring skills (`write-plan` writes
`tasks.md`/`progress.md` and hands off; the list is kept by whoever executes).

## Reports

`<slug>-report.md` is the final report, written when a task completes (multi-stage or
delegated to agents). Skip it for tasks that finish in a few tool calls.

Minimum content:
- What the task was
- What was done (files, modules)
- Validation results
- Problems and rollbacks, if any
- Status: Done / Partial / Blocked
