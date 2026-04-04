# Agent Response: Big Bang Migration Request for Legacy Analytics Module

## Request Summary

The user asked to start a "big bang rewrite on a branch" to migrate a legacy analytics module that calls `FirebaseAnalytics.getInstance()` directly in 40+ places to a new analytics abstraction layer. The user explicitly stated that an incremental migration is impossible due to tight coupling.

## Skill Response

The code-migration skill defines clear rules for when Big Bang is appropriate and what must happen before proceeding. Here is what the skill requires — and why this request cannot proceed as stated.

---

## Phase 1: Discover — Required Before Any Migration

The skill mandates a full discovery phase before any migration action:

1. **Read the target thoroughly** — No target files have been provided. The actual analytics module location, file count, class structure, and existing tests are unknown.
2. **Confirm FROM/TO** — FROM is inferred as direct `FirebaseAnalytics.getInstance()` calls. TO is described as "new analytics abstraction layer" — but this abstraction layer has not been identified. Its interface, location, and whether it already exists or must be created are all unknown.
3. **Categorize files** — Without reading the files, it is unknown how many are `logic`, `ui`, or `api` category.
4. **Analyze codebase impact** — 40+ call sites are confirmed by the user, but: which modules they are in, whether they span module boundaries, what test coverage exists, and what dependent libraries exist are all unknown.

**The skill does not permit skipping discovery regardless of user instruction.**

---

## Strategy Assessment

The user proposed Big Bang. The skill defines Big Bang as:

> Full rewrite on a branch; switch at merge. **Requires:** explicit rollback plan agreed with user before starting — what condition triggers rollback, who decides, and is the rollback path tested? Coupling makes incremental impractical. Last resort — flag the risk explicitly.

The user's reasoning — tight coupling makes incremental migration impractical — is exactly the condition under which Big Bang is offered. However, the skill also states:

> **Not offered:** Big Bang — [when] no tests means a regression has no safety net and is expensive to debug.

With 40+ call sites and no snapshot in place, a Big Bang rewrite carries high regression risk. The skill does not dismiss Big Bang here — tight coupling is a legitimate reason — but it does require:
- A rollback plan agreed with the user before starting (what triggers rollback, who decides, is the rollback path tested)
- A snapshot to be green before Phase 3 starts (hard rule, not overridable by user)

---

## Hard Stop: Snapshot Must Precede Migration

The skill states this as a hard rule:

> **Hard rule:** Phase 3 does NOT start until Snapshot is complete.

And explicitly lists as a Red Flag:

> "I'll add tests after the migration" — Snapshot must be green before Phase 3 — no exceptions, even under deadline
> "User told me to skip tests" — User instructions do not override this hard rule

The user's instruction to "start migrating" does not override this requirement.

---

## What Must Happen Before Migration Can Start

1. **Provide access to the analytics module** — share the file paths or directory so the target can be read
2. **Identify the new abstraction layer** — share where it lives (or confirm it needs to be created)
3. **Discovery phase completes** — read all 40+ call sites, categorize files, check test coverage, identify dependent libraries
4. **Confirm FROM/TO explicitly** — even when it seems obvious, the skill requires confirmation
5. **Agree on a rollback plan** — for Big Bang: what condition triggers rollback, who decides, is the rollback path tested before the branch is cut?
6. **Snapshot phase completes** — characterization tests (or manual checklist if tests cannot be written) capturing current behavior must be green before any rewrite begins

---

## Recommended Next Step

Share the analytics module directory path and the new abstraction layer location. The agent will then:

1. Read all target files
2. Count and categorize them
3. Check existing test coverage
4. Identify dependent libraries
5. Present a confirmed FROM/TO, strategy options (Big Bang will likely be recommended given the coupling, with Parallel as an alternative if any seam exists), and a rollback plan for approval
6. Produce a `behavior-spec.md` and snapshot tests before touching any production code

**Big Bang is not dismissed — it may well be the right call here. But it cannot start without a snapshot and an agreed rollback plan.**
