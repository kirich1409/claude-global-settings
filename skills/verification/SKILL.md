---
name: verification
description: >-
  Decide how a code change will be proven correct, and hold the line on that decision.
  Covers the L0-L5 verification pyramid, the public-API test gate, P0-P3 test priorities,
  per-task-type routing (feature / bug fix / migration / version bump / refactor / infra /
  UI / performance), before-state baselines, and the finalize+acceptance quality gates.

  Use when: planning how to test a change, "what level of testing does this need",
  "do I need a test for this", "how do I verify this migration", "capture a baseline",
  "what's the source of truth for done", choosing between unit/UI/E2E/manual verification,
  or before declaring an implementation finished.

  Do NOT use for: running the checks themselves (use check), the code-quality review loop
  (use finalize), acceptance against a spec (use acceptance), or authoring test code
  (use write-tests), or authoring a structured test-plan document with enumerated cases (use generate-test-plan — this skill decides *which levels and why*, that one writes the cases).
---

# Verification

How a change gets proven correct. This skill owns the *decision* — which levels apply, what
counts as the source of truth, when a test is required. Running the checks belongs to
`check`; the quality loop belongs to `finalize`; acceptance against a spec belongs to
`acceptance`.

Load the reference file for the phase you are in. Each is self-contained.

| File | Covers |
|---|---|
| `references/pyramid.md` | Levels L0-L5, when L5 is mandatory, running L5 autonomously, device exclusivity, turn cost, log capture |
| `references/priorities.md` | Public-API test gate, P0-P3 priorities, non-UI test plans, broken-test ownership, sources of truth |
| `references/task-types.md` | Routing matrix by task type, testability gate, before-state baseline |

## Choosing a level

Start at L0 and go up only as far as the change warrants. The levels are ordered — each
assumes the one below it passes.

| Level | Name | Meaning |
|---|---|---|
| L0 | Build | The affected app/module compiles. Implicit entry gate for every code change. |
| L1 | Static analysis | Lint, typecheck, dependency audit. Applies always. |
| L2 | Unit tests | Fast, no device, pure logic. |
| L3 | UI tests | Automated, needs emulator/device. |
| L4 | E2E | Full automated flow. |
| L5 | Manual verification | Mobile MCP or `manual-tester` against a running app. |

**L5 is mandatory for** library version bumps (patch included), tech/framework migrations,
infra-layer changes (network, storage, auth, DI), and anything described as "should not
affect behaviour" — verify at runtime rather than assuming.

Details, including how to run L5 without burning turns, are in `references/pyramid.md`.

## The two gates

`finalize` and `acceptance` are orthogonal and both apply before a task is called done —
not merely before merge. `finalize` checks *how the code is written*; `acceptance` checks
*what the code does*. Neither substitutes for the other, and a one-off `code-reviewer` run
closes neither.

Exemptions: documentation-only edits, configuration without logic, and one-line mechanical
changes with an obvious result. An exemption drops the ceremony, not the proof — config
still needs its own minimal verifier (`validate-config`, a schema check, a dry run) before
"done".

Scale the reviewer panel to the change. A wide, risky diff earns the full triggered set; a
narrow one does not. Cutting the panel on a genuinely broad artifact has cost real gaps
before — a spec review trimmed from five reviewers to three missed a drag-positioning
problem that the UX and performance reviewers would each have caught. Judge by the surface
area of the change, not by a fixed rule in either direction.
