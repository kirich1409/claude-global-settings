# Phase 1: Discover — Analytics Module Migration

## What Was Read

No source files were provided (simulated scenario). The task description gives us the following facts:

- **Target:** legacy analytics module
- **FROM:** Firebase Analytics SDK — direct usage of `FirebaseAnalytics.getInstance()` in 40+ places
- **TO:** new analytics abstraction layer (in-house interface, details not specified)
- **Scope:** 40+ call sites across the module; described as "tightly coupled"
- **User-requested strategy:** Big Bang

---

## Inferred FROM / TO

| | Technology |
|---|---|
| **FROM** | Firebase Analytics SDK — `FirebaseAnalytics.getInstance()` called directly at 40+ sites |
| **TO** | New analytics abstraction layer — interface-based, details to be confirmed |

These are inferred from the task description. Confirmation from the user is required before Phase 2.

---

## Categorization

Based on the description, the analytics module is:

- **`logic`** — event tracking, session management, user properties: pure data/business logic
- **`api`** — the abstraction layer boundary is a public interface consumed by callers across the codebase

No `ui` category is indicated.

---

## Codebase Impact Analysis

| Factor | Finding |
|--------|---------|
| **Call sites** | 40+ direct `FirebaseAnalytics.getInstance()` usages |
| **Module boundary** | Unknown — likely mixed into a larger module (tight coupling implies no isolation) |
| **Test coverage** | Not described — must verify before Phase 2 |
| **API stability** | Internal change to the module; public interface changes (new abstraction layer replaces direct SDK calls) |
| **Hidden consumers** | Must check: Proguard/R8 keep rules for `com.google.firebase.analytics`, any CI scripts referencing Firebase Analytics, any dependency injection setup wiring `FirebaseAnalytics` directly |
| **Incremental feasibility** | Explicitly ruled out by user — tight coupling makes it impractical |

---

## Strategy Options

**Option A — Parallel (Expand-Contract)** — recommended

> **Preparation:** Introduce the new analytics abstraction interface. Verify it compiles alongside the existing code.
> **Migration:** Implement the new abstraction backed by Firebase Analytics as a bridge (Direction A — implementation-first). Then swap each of the 40+ call sites from `FirebaseAnalytics.getInstance().logEvent(...)` to the abstraction, one file at a time. Each file leaves the build green.
> **PRs:** PR 1: module isolation + behavior-spec + characterization tests. PR 2: new abstraction interface + Firebase-backed bridge implementation. PR 3–N: caller migration in batches (by feature area or layer). PR final: bridge cleanup + Firebase dep removal.
> **Effort:** High
> **Risk:** Medium
> **Why:** 40+ call sites is too many for in-place and too spread for a single safe merge. The abstraction interface is a natural seam — implement it once, then migrate callers one-by-one with a continuously green build and independently rollbackable steps.

---

**Not offered: In-place** — 40+ direct SDK usages with no test coverage described means there is no safety net. A broken build mid-migration would be expensive to diagnose.

---

**User-requested: Big Bang — conditionally accepted, with mandatory pre-conditions**

The skill treats Big Bang as a last resort. The user's stated reason — that the coupling makes incremental migration impossible — is a legitimate trigger condition. However, the skill imposes a hard requirement before Big Bang may start:

> **Big Bang requires an explicit rollback plan agreed with the user before starting — what condition triggers rollback, who decides, and is the rollback path tested?**

This is not optional. It is a hard gate in the skill. Without it, Phase 2 cannot begin.

---

## STOP: Big Bang Rollback Plan Required

The user has chosen Big Bang. Before any code is touched, the following must be agreed explicitly:

**Three questions that must be answered before Phase 2 starts:**

1. **Rollback trigger condition:** What observable state means "this migration has failed and we roll back"? Examples: CI red for more than N days, a production incident caused by the new abstraction, a deadline missed.

2. **Decision authority:** Who decides to pull the rollback trigger? The team lead? A specific engineer? A group vote?

3. **Rollback path tested:** The branch will diverge significantly from main during a big bang rewrite. How do we validate that we can actually return to the old state if needed — is the old implementation preserved in a tag or branch, and has anyone verified it still builds?

Additionally, before Phase 2 begins, the following confirmations are still needed:

- **FROM/TO confirmation:** Is the target technology confirmed as Firebase Analytics SDK → in-house abstraction interface? What is the interface called and where does it live?
- **Test coverage baseline:** Are there any existing tests for the analytics module? (This affects the snapshot strategy — if there are none, characterization tests must be written first.)
- **Module boundary:** Is the analytics module in its own Gradle module, or embedded in a larger one? (Affects whether module isolation is a preparation step.)

---

## What Happens Next

Once the rollback plan is agreed and the confirmations above are provided, Phase 1 completes with:

1. A `migration-checklist.md` covering one row per file in the analytics module (name, category, strategy, snapshot method, dependencies) — 40+ files means this list is generated before any code is touched.
2. A `behavior-spec.md` capturing what the analytics module currently does — events logged, user properties set, session handling, error paths.
3. **User approval of both documents** before Phase 2 (Snapshot) begins.

**Phase 2 does not start until:**
- [ ] Rollback plan agreed (trigger condition + decision authority + rollback path tested)
- [ ] FROM/TO confirmed by user
- [ ] Module boundary clarified
- [ ] Test coverage baseline established
- [ ] migration-checklist.md presented and approved
- [ ] behavior-spec.md presented and approved
