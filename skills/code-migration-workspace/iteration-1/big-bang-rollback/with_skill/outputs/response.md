# Simulated Response: Big Bang Rewrite — Firebase Analytics Migration

**Skill applied:** `code-migration`
**Task:** Migrate legacy analytics module away from direct `FirebaseAnalytics.getInstance()` calls (40+ call sites) to a new analytics abstraction layer.
**User instruction:** "Let's just do a big bang rewrite on a branch. Start migrating."

---

## What I Do — and Why I Stop Before Touching Any Code

The skill's workflow is:

```
DISCOVER → CONFIRM → SNAPSHOT (must be green) → MIGRATE → VERIFY + CLEANUP
```

The user has effectively pre-chosen the strategy ("big bang rewrite on a branch"), which maps to the **Big Bang** strategy in the skill's strategy reference. However, the skill contains an explicit, non-negotiable requirement for this strategy:

> **Big Bang** — Requires: explicit rollback plan agreed with user before starting — what condition triggers rollback, who decides, and is the rollback path tested?

This is not a suggestion. The skill treats it as a prerequisite on the same level as "snapshot must be green before Phase 3." The answer to the key question is therefore:

**I do not start migrating. I stop to establish a rollback plan first.**

---

## Phase 1: Discover — What I Do

Before I can even propose options or confirm the strategy, I need to read the target and gather facts. I would:

1. **Read the analytics module** — all files, all call sites, all imports referencing `FirebaseAnalytics`.
2. **Infer FROM/TO:**
   - FROM: `com.google.firebase:firebase-analytics` accessed directly via `FirebaseAnalytics.getInstance()` at 40+ call sites
   - TO: a new analytics abstraction layer (interface + implementation — I'd read the new abstraction to understand its surface)
3. **Categorize** the target:
   - `logic` — event tracking calls, parameter building, user property setting
   - `api` — the public surface that callers depend on (if the module exposes its own facade, it's an `api` target; if callers call Firebase directly, the coupling is at the call site level)
4. **Analyze impact:**
   - 40+ call sites across how many files/modules? Search imports to count.
   - Hidden consumers: Proguard/R8 keep rules referencing Firebase class names, any CI scripts or Gradle tasks invoking analytics setup, any dynamic event registration.
   - Existing test coverage: characterization tests? instrumented tests? none?
   - Does the new abstraction interface map 1:1 to Firebase's API, or do event names/parameter shapes change?

5. **Confirm FROM/TO with user** — even though the user said "start migrating," the skill requires confirmation of FROM/TO before proceeding. I infer it from the code, but I state it explicitly and wait for acknowledgment.

---

## Phase 1: Strategy Proposal

Given what the user described (40+ call sites, tight coupling making incremental impractical), the skill allows me to present Big Bang as an option — but I am required to flag the risk explicitly and establish the rollback plan before proceeding.

Here is how I present the options:

---

> **Option A — Big Bang (branch rewrite)** *(as requested)*
> Preparation: Agree on a rollback plan before writing a single line — what condition triggers abandoning the branch (e.g., snapshot tests can't be made green, verify fails, deadline hit), who decides to roll back, and how do we verify the rollback path works (does reverting to the old branch + old Firebase SDK leave the app fully functional?).
> Migration: Full rewrite of all 40+ call sites on a feature branch; switch at merge.
> Effort: High
> Risk: High — the entire module is dark until the branch merges; if a regression is found late, there is no incremental revert path.
> Why: 40+ direct `FirebaseAnalytics.getInstance()` calls make the Parallel strategy impractical without first extracting an interface — which is essentially what Branch by Abstraction would do. If the coupling is truly that deep and the team accepts the merge risk, Big Bang is a legitimate last resort. But only with an agreed rollback plan.

> **Option B — Branch by Abstraction**
> Preparation: Introduce an `AnalyticsTracker` interface that mirrors the call sites. The new abstraction layer almost certainly already defines this — confirm it matches.
> Migration: Introduce the interface → implement it wrapping `FirebaseAnalytics` → compile-swap all 40+ call sites to go through the interface (each is a mechanical find-replace) → add the new abstraction implementation behind the interface → swap the DI binding → delete the Firebase implementation.
> Effort: Medium-High (40+ call sites, but each swap is mechanical)
> Risk: Medium — callers change to use the interface, which is a one-time mechanical change, but the build stays green at every step.
> Why: The coupling is at the call site, not at a module boundary. Introducing an interface first decouples call sites from the SDK, after which swapping the implementation is safe and independently rollbackable. This is likely cheaper in total risk than Big Bang despite the upfront work.

**My recommendation is Option B.** The user's diagnosis ("tightly coupled") correctly identifies why in-place or parallel won't work as-is — but the root cause is the absence of an interface, not a fundamental unsuitability for incremental migration. Branch by Abstraction addresses that directly. I would say so explicitly rather than just agreeing with the user's "big bang" framing.

That said, if the user confirms they want Big Bang, I proceed — but only after the rollback plan is established.

---

## The Rollback Plan Conversation (if user confirms Big Bang)

Before writing any code, I ask these three questions (one per round, per the communication style rule):

**Round 1:** What condition triggers rollback? (e.g., "snapshot tests cannot be made green within X days," "verify phase reveals behavioral regressions we can't fix in time for the release," "scope turns out larger than 40 files")

**Round 2 (after answer):** Who has authority to call the rollback — is this a solo decision or does it need sign-off?

**Round 3 (after answer):** Is the rollback path tested? Specifically: if we abandon the branch and revert to `main`, does the old Firebase-based module still compile and run correctly, or are there infrastructure changes (Gradle version bumps, SDK version changes) that would break the old code?

Only after all three questions are answered and documented do I proceed to Phase 2: Snapshot.

---

## Phase 2: Snapshot — What Must Happen Before Code Changes

The skill is explicit: **Phase 3 does not start until Snapshot is green.** For this target:

- **`logic` targets:** Write characterization tests capturing what the analytics module actually does — event names, parameter shapes, user property calls, any quirks (e.g., events silently dropped when analytics is disabled, null parameter handling). Run them green.
- **`api` targets:** List every public surface. List every call site (40+ by the user's count — verify with a codebase search). Record as a behavioral checklist.
- Produce a `behavior-spec.md` documenting the public interface, normal behaviors, edge cases, and quirks. Present it to the user for confirmation before Phase 3.

If existing tests are broken or nonexistent and cannot be made green: stop, discuss with user, fix snapshot first. The user saying "just start migrating" does not override this rule (see Red Flags table: "User told me to skip tests" — this is an explicit Red Flag in the skill).

---

## Summary: The Sequence

1. **Read and categorize** the analytics module and the new abstraction layer.
2. **Confirm FROM/TO** with the user.
3. **Present Option A (Big Bang) and Option B (Branch by Abstraction)** — recommend B, explain why.
4. **If user chooses Big Bang:** establish rollback plan (3 questions, one per round) before any code changes.
5. **Snapshot:** write characterization tests, produce `behavior-spec.md`, get user confirmation.
6. **Only then:** begin the branch rewrite.

The direct answer to the key question: **I stop to establish a rollback plan first.** The skill's Big Bang strategy definition makes this non-negotiable. Starting to migrate before agreeing on a rollback plan, snapshot coverage, and behavior spec would violate three distinct rules in the skill — and the most likely outcome of skipping those steps is discovering a regression late in a branch with no incremental revert path, which is exactly the failure mode Big Bang is most susceptible to.
