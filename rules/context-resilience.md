# Context Compaction Resilience

For long multi-stage tasks, persist state to a file so work survives context compaction. Three canonical files live in `./swarm-report/` (must be in `.gitignore`):

| File | Purpose | Lifetime |
|---|---|---|
| `<slug>-state.md` | Operational checklist for any long task — plan execution, multi-step refactor, batch fix | Delete after task completes |
| `<slug>-e2e-scenario.md` | Running-app verification scenario; single source of truth for "verified". Owned by `/acceptance` when invoked | Survives across re-runs of acceptance |
| `<slug>-debug.md` | Bug investigation: repro steps, observed vs expected, hypotheses, root cause. Picked up by `acceptance` Branch 3 and `create-pr` for bug-fix PR bodies | Stays as audit trail |

A fourth file, `<slug>-report.md`, is the final report (see Reports below).

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

Every step carries an explicit `→ verify: <check>` — the concrete signal that proves the step is done (a passing test, a command exit code, an observed UI state). A step without a verifiable check is a weak goal: it forces a clarification round mid-task instead of letting the loop close on its own. Turn vague asks into checks up front — "add validation" → "test for invalid input passes", "fix the bug" → "regression test reproducing it now passes".

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

## Re-read rule

Before each action that depends on prior state — **Read the file first**. Completed steps (`[x]`) are not redone; resume from the first `[ ]`. Mark `[x]` only after the action is verified, never speculatively. If a step is rolled back, edit the file — the file is the truth, the chat is not.

On `/compact` or session end the active state files are the recovery point: current goal, open TODOs, verification commands, key architectural decisions all live there.

## Reports

`<slug>-report.md` — final report saved when the task completes (multi-stage or agent-delegated). Skip for tasks completable in a few tool calls.

Minimum content:
- Task description
- What was done (files, modules)
- Validation results
- Issues and rollbacks (if any)
- Status: Done / Partial / Blocked
