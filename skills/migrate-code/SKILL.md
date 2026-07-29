---
name: migrate-code
description: "Behavior-preserving in-project technology migration: library to library, approach to approach, UI paradigm, or module type. Use when: \"migrate library\", \"replace framework\", \"swap dependency\", \"View to Compose\", \"port module to KMP\", swapping a DI container, moving off a deprecated API. Runs a phased loop — analysis, rulebook, translation, compile, smoke, behavior parity against a chosen judge — scaled to the size of the job. Do NOT use for: a full language or framework port of an entire application, a platform migration, a network protocol migration, a data schema migration, or build/config-only work (build edits that accompany a code migration stay in scope)."
---

# Migrate Code

Move a codebase from one technology to another **without changing externally observable
behavior**. The skill owns the decision structure — what is in scope, who judges correctness,
how the work is ordered, when to stop — and a phased loop that scales from a three-file
dependency swap to a cross-cutting graph rewrite.

**Key principle: the rules are the artifact, not the diff.** Translation is mechanical once a
RULEBOOK exists. A systematic defect is a defect in a rule; you fix the rule and re-run, never
patch the individual file. See `references/rulebook.md`.

**Second principle: no judge, no migration.** "Behavior preserved" is a claim, and a claim needs
a referee. Phase 0 names that referee before any code moves. The compiler is a referee only for
some migrations — see `references/verification-matrix.md`.

## Contents

| File | Covers |
|---|---|
| [scope.md](references/scope.md) | IN / OUT / borderline taxonomy, localized vs cross-cutting, STOP conditions |
| [phase-0-analysis.md](references/phase-0-analysis.md) | Analysis procedure, the nine Phase 0 outputs, risk assessment, mode selection |
| [verification-matrix.md](references/verification-matrix.md) | Levels L0-L5 defined for migration, compiler-as-referee, choosing the minimum valid level |
| [judge.md](references/judge.md) | Three judge sources, judge coverage assessment, test coupling inventory, legacy profile |
| [rulebook.md](references/rulebook.md) | Building the RULEBOOK and gap inventory, port markers, fix-the-loop |
| [rulebook-template.md](references/rulebook-template.md) | RULEBOOK skeleton to copy verbatim |
| [inventory-template.md](references/inventory-template.md) | Gap inventory skeleton to copy verbatim |
| [depmap-and-queue.md](references/depmap-and-queue.md) | Dependency map and work queue as patterns generated in place |
| [adversarial-review.md](references/adversarial-review.md) | Two reviewers in separate contexts, rule citation, arbiter |
| [migration-loop.md](references/migration-loop.md) | Phases 1-6 mechanics, lightweight path, compile placement, worked examples |
| [cross-cutting.md](references/cross-cutting.md) | Graph and layer migrations, interop bridge vs big-bang, DI container swap |
| [safety-net.md](references/safety-net.md) | Three entry branches when coverage is missing, seam trap, handoff report |

Load the reference for the phase you are in. Each is self-contained.

## Overview

The loop is the same at every size; what changes is how much of it you pay for.

```
Phase 0  Analyze          -> type, topology, judge, risk, mode
   [optional] Establish safety net    (embedded or extracted deliverable)
Phase 1  RULEBOOK + gap inventory + dependency map
Phase 2  Stress-test the rules on representative files
Phase 3  Translate (fan-out over the work queue)
Phase 4  Compile
Phase 5  Smoke
Phase 6  Behavior parity against the judge
```

Phase 0 is never skipped — it is the phase that decides how much of the rest applies. Most of what
follows is negotiable and the negotiation is explicit: `references/migration-loop.md`
§ Lightweight path lists what a small migration skips, the conditions under which it may, and what
is never skipped at any size.

The safety-net step is optional and sits **between** Phase 0 and Phase 1: it runs only when Phase 0
finds no reachable judge with the coverage that exists today.

## Scope

In scope: behavior-preserving in-project migrations — library to library, approach to approach,
UI paradigm, module type. Logical module boundaries and externally observable behavior survive the
change; the technology underneath does not.

Out of scope: full language or framework ports of an entire application, platform migrations,
protocol migrations, schema migrations, and build/config-only work. Build edits that *accompany* a
code migration (version catalogs, source-set layout) stay in scope.

Also out of scope: **authoring test code**. Assessing coverage, ranking gaps by risk, and stating
what a test must prove are in scope; writing the test bodies is handed off (see
`## Handoff for coverage gaps`).

The full taxonomy, the borderline cases, and the signals that separate a localized migration from a
cross-cutting one live in `references/scope.md`. Read it in Phase 0 — misclassifying topology is the
most expensive mistake available, because it silently invalidates the judge.

## Phase 0

Analyze before touching anything. Produces **nine** outputs, in this order:

1. Migration type, classified against the taxonomy in `references/scope.md`.
2. Topology: localized or cross-cutting.
3. Verification matrix for this migration.
4. Judge coverage assessment.
5. Test coupling inventory.
6. Risk assessment: blast radius, volume, known hazards.
7. Legacy-profile detection: no usable judge on the changed surface (no tests reach it, or output 5
   classified all of its coverage as coupled), or no regression pass before release.
8. Proposed execution mode.
9. Safety-net decision.

Outputs 4 and 5 are separate: how much of the migrated surface the judge actually watches is a
different question from how tightly the existing tests are welded to the outgoing technology.

Three modes are available — adaptive (default), autonomous, human-gated — chosen as a function of
risk against verification cost. **The final call on the mode belongs to the human.** Procedure and
mode criteria: `references/phase-0-analysis.md`.

## Optional step: establish a safety net

Runs only when Phase 0 finds no reachable judge. Three entry branches — stop and build coverage
first, take a golden-master baseline, or grow coverage as you go — with selection criteria, the
seam trap (refactoring to create a test seam is itself a mini-migration; budget it, do not recurse),
and the embed-or-extract deliverable boundary: `references/safety-net.md`.

If no branch produces a valid judge, see `## Red Flags / STOP`.

## Phase 1

Write the RULEBOOK, the gap inventory, and the dependency map.

The RULEBOOK is the single source of translation decisions and is **read-only inside the loop** —
amendments happen between batches, never mid-batch. The gap inventory carries one row per site that
cannot be translated mechanically. See `references/rulebook.md` plus the two copy-verbatim skeletons
`references/rulebook-template.md` and `references/inventory-template.md`.

The dependency map and the work queue are **patterns you generate in place** for the stack at hand,
not shipped scripts. The queue's completion predicate is "the target file exists on disk", which
makes the run resumable by reconstruction rather than by stored state:
`references/depmap-and-queue.md`.

## Phase 2

Stress-test the rules on a representative sample before fan-out. A rule that survives three
hand-picked awkward files is a rule; a rule that has only seen the easy case is a guess. Findings
route back into the RULEBOOK, not into the sampled files.

## Phase 3

Translate. Fan out over the work queue in dependency order, cycles taken as one batch. Every worker
reads the same RULEBOOK and writes nothing back to it; unrepresentable sites get a port marker and a
row in the gap inventory. Mechanics: `references/migration-loop.md`.

Adversarial review of the translated output runs two reviewers in **separate contexts** with a third
as arbiter on disagreement, and every finding must cite a specific RULEBOOK rule — a finding with no
rule behind it is a proposed rule change, not a defect: `references/adversarial-review.md`.

## Phase 4

Compile. Placement is a decision, not a constant: **by default compilation sits outside the
translation loop** because a full build per file is expensive; pulling it inside is the named
exception for stacks where an incremental typecheck is cheap. See `references/migration-loop.md`
§ Compile placement.

## Phase 5

Smoke. The narrowest run that proves the migrated path executes — the application starts and runs
it, or, for a target with no entry point (e.g. a library or SDK module), the public entry point is
constructed and called once from outside the migrated code. Cheap, early, and not a substitute for
Phase 6.

## Phase 6

Behavior parity against the judge chosen in Phase 0. This is the phase that discharges the
"behavior-preserving" claim, and it is the phase most often quietly downgraded to "the build is
green". Green build is L0. Parity criteria that do not follow from tests passing — byte-for-byte
serialization format compatibility is the recurring one — are separate acceptance criteria and must
be stated as such.

## Roles & Verification

Roles are abstract; bind them to whatever agents, models, or people the environment provides.

| Role | Does | Typical weight |
|---|---|---|
| `rule-author-role` | Writes and amends the RULEBOOK | Strong — blast radius is the whole migration |
| `implementer-role` | Translates files against the RULEBOOK | Cheaper — the decisions are already made |
| `adversarial-reviewer-role` | Reviews translated output against cited rules | Strong |
| `fixer-role` | Applies rule-driven corrections after review | Cheaper |
| `scenario-judge-role` | Executes runtime scenario parity | Depends on the judge level |
| `test-authoring-role` | Writes coverage the migration needs but does not own | Out of this skill |

Blast radius picks the weight: a wrong rule corrupts every file it touches, a wrong translation
corrupts one.

Verification levels **L0-L5 are defined in `references/verification-matrix.md`**, self-contained, in
migration terms. Pick the *minimum valid* level: the lowest level that can actually distinguish
correct from incorrect for this migration. Where the compiler catches the failure mode, the compiler
is the referee. Where it does not — runtime dependency graphs compile cleanly while broken, byte
formats change silently — the level is higher and no amount of green build substitutes.

## Handoff for coverage gaps

When Phase 0 finds coverage the judge needs and the project does not have, the gap is handed to
`test-authoring-role` as a coverage-gap handoff report with a fixed six-field schema. Fields, worked
example, and the decision rule for what happens to characterization tests after the migration:
`references/safety-net.md`.

Two constraints on the handoff:

- The report is **optional for the receiving side**. The receiver must be able to work without it;
  the report is an accelerator, not a protocol dependency.
- Automated coverage authoring is available on some stacks and not others. Outside them the role is
  filled manually — a degraded but supported mode, which is exactly why the schema carries a
  `baseline` field: a manual author needs a description of the behavior to capture, not just a
  target.

Do not confuse the two coverage artifacts: the **judge coverage assessment** (Phase 0, output 4) is
an inward measurement of how much the judge sees; the **coverage-gap handoff report** is an outward,
risk-ranked work order.

## Red Flags / STOP

Two conditions, both normative. Content owner is `references/scope.md`.

1. **No valid judge at any level of the matrix, and no safety net can be built.** Do not start the
   migration. There is no level at which "behavior preserved" could be demonstrated, so the work
   would produce an unfalsifiable claim. This is a NO-GO to report, not an obstacle to route around.

2. **Interruption mid-migration is a normal outcome, not a failure** — the work queue is resumable,
   port markers record what is unfinished, and an interop bridge leaves both implementations live.
   The rule that makes it normal: **stop only on a green build.** A partially migrated tree that
   compiles and passes its existing tests is a legitimate resting state; one that does not is
   damage.
