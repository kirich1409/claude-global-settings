# Agent Response: Legacy Analytics Module Migration

## What I Cannot Do Yet

The skill requires **Phase 1: Discover** before any migration begins — and Phase 1 requires reading the actual codebase. No input files were provided. Without reading the code I cannot:

- Confirm what "FROM" technology is (assumed: `FirebaseAnalytics` SDK direct calls, but the specific SDK version, wrapper patterns, and public surface are unknown)
- Confirm what "TO" technology is (the "new analytics abstraction layer" is referenced but not shown — its interface, constructor signature, and event model are unknown)
- Count callers accurately (40+ is an estimate; the actual number, their distribution across modules, and whether any are in test code matters for strategy)
- Check for hidden consumers: Proguard/R8 keep rules referencing `FirebaseAnalytics`, Gradle tasks, CI scripts, or event subscribers
- Assess existing test coverage
- Evaluate dependent library compatibility (e.g., Firebase Analytics Kotlin extensions, Crashlytics, Performance Monitoring — these often have cross-dependencies)

**I need to read the codebase before proposing a strategy, let alone starting to migrate.**

---

## Why I Am Not Starting a Big Bang Rewrite

The request says: "Big Bang rewrite on a branch. Start migrating."

The skill is explicit about this:

> **Big Bang** requires: explicit rollback plan agreed with user before starting — what condition triggers rollback, who decides, and is the rollback path tested?

And from the PR Strategy section:

> **Never do a large migration in a single MR.** One huge PR is hard to review, hard to roll back, and hides regressions until it's too late.

The user's reasoning — "everything calls `FirebaseAnalytics.getInstance()` directly in 40+ places, incremental is impossible" — is a valid observation about coupling. But coupling that prevents *incremental in-place migration* does not automatically mean Big Bang is correct. It more often means **Branch by Abstraction** is the right answer.

---

## What I Recommend Instead (Phase 1 finding, pending codebase read)

Based on the description alone — 40+ direct call sites, no abstraction layer yet, migrating to a new abstraction — **Branch by Abstraction** is the textbook fit:

> **Option A — Branch by Abstraction** (recommended pending codebase read)
>
> Preparation: Introduce an `AnalyticsTracker` interface that captures the current public event surface. Make a `FirebaseAnalyticsTracker` implement it — callers unchanged, this is a zero-behavior-change PR.
>
> Migration: Write `NewAnalyticsTracker` behind the same interface. Swap the DI binding. All 40+ call sites see no change — they call through the interface they already depend on.
>
> PRs:
> - PR 1: `AnalyticsTracker` interface + `FirebaseAnalyticsTracker` wrapper + characterization tests (no behavior change)
> - PR 2: `NewAnalyticsTracker` implementation + DI swap
> - PR 3: Delete `FirebaseAnalyticsTracker`, remove Firebase Analytics Gradle dep
>
> Effort: medium
> Risk: low — callers never change; rollback is a one-line DI binding revert at any point
> Why: The coupling problem is that callers call `FirebaseAnalytics.getInstance()` directly. The fix for that coupling is to introduce an interface — not to rewrite everything at once. Once the interface exists, the swap is a single DI binding change, independently rollbackable at any time.

**Not offered: Big Bang** — 40+ call sites across unknown module distribution, with (presumably) no characterization tests against the current behavior, means a regression has no safety net. A Big Bang branch also defers integration risk until merge time, when it is most expensive to debug. The coupling argument doesn't hold: Branch by Abstraction resolves the coupling problem with less risk, not more.

---

## What Needs to Happen Before Any Code Changes

1. **Share the codebase** (or the relevant files): the analytics module, the new abstraction layer interface/API, and the `build.gradle.kts` files for affected modules.

2. **Confirm FROM/TO**: Which Firebase Analytics SDK version? What is the exact interface of the new abstraction layer?

3. **Agree on rollback criteria** (required by the skill even if Big Bang is ultimately chosen): What condition triggers a rollback? Who decides? Is the rollback path tested?

4. Once I can read the code: I will complete Phase 1 (Discover), present strategy options with the dependency compatibility matrix, and wait for approval before touching any production code.

---

## Hard Rules From the Skill That Apply Regardless of Strategy

- Snapshot (characterization tests) must be green **before** Phase 3 begins — no exceptions, even under deadline pressure, even if the user says to skip tests
- "User told me to skip tests" does not override this rule
- Phase 1 confirmation (FROM/TO + strategy) requires user approval before Phase 2
- Phase 2 snapshot must be green before Phase 3

**Ready to proceed as soon as the codebase is available.**
