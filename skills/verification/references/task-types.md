# Routing by task type

## Testability gate

Write tests when **both** hold:

1. The coverage approach is clear — a natural test boundary exists for the behaviour (pure
   function, API contract, known UI interaction).
2. The effort fits the task's budget — writing the test does not cost more than the change
   itself for simple cases, and does not require building test infrastructure from scratch.

If either fails, document the reason in the plan and proceed without tests for that scope.
"Unclear how to test this" and "setup cost is prohibitive" are valid reasons; "didn't feel
like it" is not.

This gate governs **discretionary** scope — which pyramid levels, internal behaviour. It does
not waive the minimum for public API: a changed **public** symbol still has to satisfy the
public-API gate in `priorities.md` (covered by a test or marked trivial). If the test cost
really is prohibitive for a public symbol, route it to a **tracked exception** (the
`@Ignore`-with-issue pattern) so the gap stays visible, never silently dropped.

## Reduce verification cost at planning time

Do not only decide *whether* to test — assess how hard verification will be and lower its
cost **before** implementing:

- Surface hard to reach (deep in a flow, needs a real backend, slow to get to) → build a
  **sample / sandbox app** or harness that exercises the changed behaviour in isolation;
  prototype and debug there first, then port into the real app. Debugging only in the real
  app is the slow path.
- UI → prefer **screenshot tests** plus a screenshot baseline; run several emulators or form
  factors when the change is layout- or device-sensitive.
- Temporary simplifications that make a verifiable prototype reachable sooner are fine (see
  disposable tests in `pyramid.md`) — but remove or harden them before `finalize`.

The goal is the cheapest path to a *verifiable* prototype, not deferring testing. Decide
simplifications and what to capture (baselines, screenshots, test data) here, during
planning — not mid-implementation.

## Routing matrix

| Task type | Source of truth | Min. pyramid | When to write tests | Notes |
|---|---|---|---|---|
| Feature | Spec / test plan / AC list | L1-L5 (L5 if there is a UI surface) | After implementation; before, if the AC are clear (TDD) | — |
| Bug fix | `swarm-report/<slug>-debug.md` — reproduction steps | L1-L2, plus L5 for a UI regression | **Before the fix** — failing test first, then fix | Red-green: the test proves the bug exists, then that it is gone |
| Tech migration | Before-state baseline | L1 + **L5 mandatory** | Before migrating — establish coverage of the migrated behaviour as part of the baseline | Capture the before-state first |
| Library version bump | Before-state baseline | L1 + **L5 mandatory** | Confirm existing tests pass; add tests where gaps appear | Capture the before-state if there are no tests |
| Refactor | Before-state baseline (tests as proxy where they exist) | L1-L2, plus L5 if there is a UI surface | Before refactoring where coverage has gaps | Behaviour must be 1:1 with the before-state |
| Infra change (network / storage / auth / DI) | Spec / requirements | L1 + **L5 mandatory** | After implementation | — |
| UI / design task | Figma / screenshots | L1 + L3 + L5 | After implementation | Visual comparison against the mockup |
| Performance work | Benchmark baseline — before/after numbers | L0 + benchmark measurement | Capture baseline before; measure the delta after | The improvement is a measured delta (Macrobenchmark / Perfetto), never "feels faster" |
| Investigation / research | Research result document | L1 only if code was written | N/A when no code changes | No pyramid when no code is written |

**L0 (Build) is the implicit entry gate for every line changed** — the affected part (the
relevant app/module, not always the whole repo) must compile before any L1+ runs. The
"Min. pyramid" column lists levels *above* L0 and never waives it. No code change → no L0
(research, for instance).

## Watch-red-first

Where the matrix says to write the test **before** the code (bug fixes; features with clear
AC), the red-green discipline applies stepwise: run the test and **watch it fail** first —
that proves the test actually exercises the missing or broken behaviour — then write the
minimal code, then watch it go green. A test never observed red proves nothing; it may have
been passing by accident (wrong assert, wrong path, tautology).

This is **not** global strict TDD. Where the matrix says tests come **after** implementation
(a feature without early AC, infra, UI/design), or where prototype-first is legitimate,
watch-red-first does not apply. It sharpens only the cells where red-green was already
chosen; it does not introduce a new mode or require deleting code written before a test.

## Before-state baseline

A durable snapshot of current system behaviour, taken **before any changes**, detailed
enough to confirm the changed system behaves identically.

### What qualifies

1. **Passing tests cover the behaviour being changed** → the test suite *is* the baseline.
   No extra capture needed — green before is the spec for after.
2. **No test coverage** → capture manually before starting:
   - UI: screenshots of every affected screen plus a `manual-tester` exploration session,
     recorded in `swarm-report/<slug>-baseline.md`.
   - API / backend: response-shape snapshots for the affected endpoints.
   - Performance-neutral claims: current benchmark numbers.

**Shortcut:** establishing test coverage of the behaviour before migrating satisfies both the
baseline requirement and the `write-tests` step in one pass.

**Sufficiency check:** "Could I hand this baseline to someone who has never seen the system
and have them confirm the migration succeeded?" If yes, it is sufficient.

### What is not a baseline

- "It should be fine."
- Code review or static analysis of the change — they check intent, not runtime behaviour.
- A passing build — it proves compilation, not behaviour.
