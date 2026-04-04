# Phase 1: Discover — Analytics Module Firebase → New Abstraction Layer Migration

## What I found

**FROM:** Firebase Analytics SDK internals — `FirebaseAnalytics.getInstance()` called directly in 40+ places across the analytics module
**TO:** New analytics abstraction layer (interface-based, implementation-agnostic)

**Categorization:**
- `logic` — event tracking, user property management, session handling (all wired directly to Firebase)
- `api` — the analytics module's public surface (currently leaks Firebase types; callers depend on `FirebaseAnalytics` directly)

**Codebase impact (simulated from description):**
- **Callers:** 40+ direct `FirebaseAnalytics.getInstance()` call sites — this is not just 40 callers of a module boundary, it is 40 places where Firebase SDK internals are used raw
- **Module boundary:** The analytics module is not isolated — Firebase is imported and used everywhere the module is touched
- **Test coverage:** Not stated, but tight coupling to `FirebaseAnalytics.getInstance()` (a singleton with no injection point) strongly suggests tests are either absent or Firebase-dependent and not runnable in unit test context
- **API stability:** The public interface will change — callers currently use Firebase types directly; the new abstraction layer exposes a different surface
- **Hidden consumers:** Firebase-specific Gradle dependencies, likely `google-services.json` configuration, possible ProGuard keep rules for Firebase classes, CI scripts that may initialize Firebase for integration tests
- **Dependent libraries:** The existing `firebase-analytics` dependency becomes the implementation detail behind the abstraction; the new layer likely introduces an interface artifact and a Firebase-backed implementation artifact

---

## Strategy options

**Option A — Parallel (Expand-Contract)** ⭐ recommended
Preparation: Introduce the abstraction interface (`AnalyticsTracker` or equivalent) and a `FirebaseAnalyticsTracker` implementation that delegates to the existing Firebase calls. Wire the interface via DI.
Migration: Swap callers from `FirebaseAnalytics.getInstance()` to the injected interface one-by-one, in batches by module or layer. Each batch compiles and tests green independently.
PRs: PR 1: interface + Firebase implementation + DI wiring (no behavior change). PR 2: characterization tests (snapshot). PR 3–N: caller migration batches (data layer → domain → UI). PR N+1: cleanup (remove raw `getInstance()` usages, tighten the Firebase dep to implementation-only).
Effort: high
Risk: low-medium
Why: 40+ call sites spread across a module that leaks Firebase internals is exactly the scope where incremental migration pays off — each batch is independently rollbackable and CI catches regressions at each step. The user's stated reason for Big Bang ("too tightly coupled for incremental") applies to the Firebase singleton, which Parallel solves by introducing the interface first and migrating callers one step at a time.

---

**Not offered: Big Bang** — and here is why this matters enough to push back on directly.

The user's reasoning is: "everything calls `FirebaseAnalytics.getInstance()` directly in 40+ places, so incremental is impossible." This is a coupling observation, not a proof that Big Bang is the right response to it.

Big Bang on a 40+ call site rewrite means:
- A long-running branch that diverges from main — merge conflicts compound over time
- No ability to ship partial progress — the whole thing ships at once or not at all
- If a regression appears post-merge, the diff to bisect is enormous
- The skill explicitly classifies Big Bang as **last resort** and requires an agreed rollback plan before starting

The coupling argument dissolves once an abstraction interface is introduced as the first step. That step is small (one interface, one implementation class, one DI binding change) and does not require touching the 40+ call sites yet. After that first PR, every caller can be migrated independently. The coupling is not a blocker for incremental — it is the first thing the incremental plan addresses.

---

## Stopping here — Big Bang rollback plan required before proceeding

The skill defines Big Bang as requiring:

> **Requires:** explicit rollback plan agreed with user before starting — what condition triggers rollback, who decides, and is the rollback path tested?

Before I can proceed with any strategy — including before Phase 2 (Snapshot) — I need answers to three questions. I will ask one at a time as the skill's communication rules require, but I am surfacing all three now so you can see the full gate:

**Question 1 (blocking):** What is the rollback condition?

What observable state triggers "we roll this back"? Options:
1. Any test failure on the migration branch after merge
2. A specific failure rate threshold in production (e.g., >X% crash rate on analytics events)
3. A deadline passes without the branch being in a mergeable state
4. A team lead or QA owner decides — specify who

This is not process overhead. A Big Bang rewrite on a 40+ file scope that merges without a defined rollback trigger means there is no agreed stopping condition if something goes wrong post-merge. That ambiguity turns a recoverable regression into a drawn-out incident.

---

**My recommendation:** Choose Option A (Parallel) instead. The "incremental is impossible" premise does not hold once the abstraction interface exists. The Parallel strategy is safer, independently rollbackable at every batch, and produces the same end state — without the Big Bang risks.

If you still want Big Bang after reading this: answer the rollback question above, then I will ask about who decides and whether the rollback path is tested. Once all three are answered and agreed, I can proceed to Phase 2 (Snapshot) on the branch.
