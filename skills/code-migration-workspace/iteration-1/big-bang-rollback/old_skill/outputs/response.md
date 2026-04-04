# Simulated Response: Big Bang Firebase Analytics Migration

## The Key Question

**Do I start migrating immediately, or stop to establish a rollback plan first?**

I stop. I do not touch a single line of code until a rollback plan is agreed with the user.

---

## What the Skill Says

The skill's strategy reference is explicit on Big Bang:

> **Big Bang** — Full rewrite on a branch; switch at merge. **Requires:** explicit rollback plan agreed with user before starting — what condition triggers rollback, who decides, and is the rollback path tested? Last resort — flag the risk explicitly.

This is not a suggestion. The word "Requires" is a hard gate. The skill also states:

> Never start migrating before snapshot is green.

And the workflow graph shows:

```
confirm → snapshot → snapshot_green? → migrate
```

Big Bang does not bypass snapshot. It does not bypass confirm. It only changes *how* migration proceeds (full rewrite on a branch rather than incremental caller-by-caller). The gates before migration remain identical.

---

## What I Would Actually Do

### Step 1 — Discover (Phase 1)

Before confirming anything, I read the analytics module thoroughly:

- Catalog every file that calls `FirebaseAnalytics.getInstance()` directly
- Identify the new abstraction layer's public interface (what `TO` looks like)
- Check whether any non-obvious consumers exist: Proguard/R8 keep rules referencing Firebase class names, Gradle tasks, CI scripts that reference analytics event names as strings
- Assess existing test coverage of the analytics module
- Confirm the public API boundary: do callers call the analytics module, or do they call `FirebaseAnalytics` directly? (The user says 40+ direct calls — that means the abstraction layer is not yet in place, so this is also an `api` category migration, not just `logic`)

### Step 2 — Confirm (with explicit Big Bang risk flag)

I present my findings to the user and propose strategy options. Given 40+ direct callsites and tight coupling, the options would realistically be:

**Option A — Big Bang (branch rewrite)** *(matches user's stated intent)*
> Preparation: Establish rollback plan before writing any code — trigger condition, decision owner, and a tested rollback path.
> Migration: Full rewrite on a branch; all 40+ callsites switch to the new abstraction in one pass; merge when green.
> Effort: High
> Risk: High — if post-merge regressions are discovered, rollback is a revert of the entire merge commit; no partial undo.
> Why: Coupling makes incremental migration impractical as stated. Last resort — the risk must be explicitly accepted.

**Option B — Branch by Abstraction**
> Preparation: Introduce `AnalyticsTracker` interface wrapping `FirebaseAnalytics`; wire existing calls through it.
> Migration: Implement new abstraction behind the interface; swap DI binding; callers never change because they already go through the interface.
> Effort: Medium (interface extraction is mechanical even across 40+ files)
> Risk: Medium — each caller swap compiles independently; rollback is a single DI binding change.
> Why: The coupling is at the call site, not in logic — introducing an interface first converts this from Big Bang to Branch by Abstraction, which is safer. Worth considering even if it feels like more setup.

I would recommend Option B, but the user has stated their preference for Big Bang. I respect that — but I flag it explicitly and wait for acknowledgment.

### Step 3 — If User Confirms Big Bang

Before any code changes, I ask the user to answer three specific questions:

1. **Trigger condition:** What observable condition triggers rollback? (e.g., "any analytics event fails to fire in staging," "crash rate increases by X% post-merge," "QA sign-off fails within N days")
2. **Decision owner:** Who decides to pull the trigger? (Tech lead, QA, product?)
3. **Rollback path:** Is rollback a `git revert` of the merge commit? Has anyone verified that path works on this repo (no rebase-squash history that would make revert painful)?

I do not accept vague answers like "we'll figure it out if needed." A rollback plan that hasn't been thought through is not a rollback plan.

### Step 4 — Snapshot (Phase 2)

Only after rollback plan is documented and agreed:

- Produce `behavior-spec.md` covering every analytics event the module currently fires: event names, parameter keys, parameter values, conditions under which each fires, and any known quirks (e.g., events that are silently dropped under certain conditions)
- Write characterization tests for the analytics logic: not "what it should do" but "what it actually does right now" — including any surprising nullability, swallowed exceptions, or event deduplication behavior
- Run all existing tests — they must pass before Phase 3 starts
- If existing tests are broken: stop, discuss with user, fix snapshot first — never proceed

### Step 5 — Migrate (Phase 3)

Only after snapshot is green. The branch already exists. Now I rewrite all 40+ callsites to use the new abstraction layer. I commit in logical batches (e.g., by feature area) so the branch history is readable and partial rollback within the branch is possible if needed.

### Step 6 — Verify + Cleanup (Phase 4)

- Re-run all snapshot tests
- Walk `behavior-spec.md` line by line against the new implementation
- Confirm every analytics event still fires correctly (manual or automated)
- Present cleanup list (old Firebase direct imports, now-unused utility classes) to user before removing
- Run `./gradlew build` — must be green before declaring done

---

## Summary Answer

**I do not start migrating immediately.**

The skill has a hard rule: Big Bang **requires** an explicit rollback plan agreed with the user before starting. This is not bureaucracy — it is the only thing that makes a full-module rewrite recoverable if it goes wrong. A Big Bang with no agreed rollback condition, no named decision owner, and no tested revert path is not a controlled migration; it is a bet.

The sequence is:

1. Discover → read all 40+ callsites, find hidden consumers
2. Confirm → present Big Bang (with risk flag) and Branch by Abstraction as options; wait for user choice
3. Rollback plan → document trigger, owner, and path before any code changes
4. Snapshot → `behavior-spec.md` + characterization tests, all green
5. Migrate → rewrite on branch
6. Verify + Cleanup → tests, behavior spec review, build green

Skipping straight to step 5 because "everything needs to change anyway" is exactly the reasoning that makes big rewrites fail silently and expensively.
