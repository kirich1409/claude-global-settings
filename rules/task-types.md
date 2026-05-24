# Task Type Routing

Routing matrix: task type → verification source of truth + testing pyramid target + when to write tests.

## Routing matrix

| Task type | Source of truth | Min pyramid | Write tests | Special |
|---|---|---|---|---|
| Feature | Spec / test plan / AC list | L1–L5 (L5 if UI surface) | After implementation; before if AC are clear (TDD) | — |
| Bug fix | `swarm-report/<slug>-debug.md` — reproduction steps | L1–L2 + L5 if UI regression | **Before fix** — write a failing test first, then fix | Red-green: test proves bug exists, then proves it's gone |
| Tech migration | Before-state baseline | L1 + **L5 mandatory** | Before migration — establish test coverage of migrated behavior as part of baseline | Capture before-state first |
| Library version bump | Before-state baseline | L1 + **L5 mandatory** | Verify existing tests pass; add where coverage gaps found | Capture before-state if tests absent |
| Refactoring | Before-state baseline (tests as proxy if they exist) | L1–L2 + L5 if UI surface | Before refactor if coverage gaps exist | Behavior must be 1:1 with before-state |
| Infrastructure change (network / storage / auth / DI) | Spec / requirements | L1 + **L5 mandatory** | After implementation | — |
| UI / design task | Figma / screenshots | L1 + L3 + L5 | After implementation | Visual comparison against mockup |
| Investigation / research | Research output document | L1 only if code produced | N/A when no code changes | No pyramid when no code is written |

## Before-state baseline

A durable snapshot of the system's current behavior, created **before any changes**, detailed enough to verify the modified system behaves identically.

### What qualifies

1. **Passing tests cover the behavior being changed** → the test suite IS the baseline. No additional capture needed — green before = spec for after.
2. **No test coverage** → capture manually before starting:
   - UI: screenshots of all affected screens + `manual-tester` exploration session documented in `swarm-report/<slug>-baseline.md`.
   - API / backend: response shape snapshots for affected endpoints.
   - Performance-neutral claims: current benchmark numbers.

**Shortcut:** establishing test coverage of the migrated behavior before the migration satisfies both the baseline requirement and the `/write-tests` step in one move.

**Sufficiency check:** "Could I hand this baseline to someone who has never seen this system and have them verify the migration succeeded?" If yes — the baseline is sufficient.

### What is not a baseline

- "It should be fine" — not a baseline.
- Code review or static analysis of the change — these check intent, not runtime behavior.
- A passing build — proves compilation, not behavior.
