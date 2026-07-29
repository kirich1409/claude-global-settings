# Scope

This file owns the IN/OUT taxonomy, the localized-vs-cross-cutting distinction, and the content of
the two STOP conditions. `SKILL.md` only reflects them; this file is the source.

The boundary in one sentence: if the logical module boundaries and the externally observable
behavior survive the change, the migration is IN; if the boundary itself is the thing being erased or
replaced, it is OUT.

## IN

Core types, each a swap of technology underneath a boundary that itself does not move:

- **Library to library** — same responsibility, different dependency (e.g. Gson to
  kotlinx.serialization, OkHttp to Ktor client).
- **Approach to approach** — same outcome, different mechanism within the same platform (e.g.
  callbacks to coroutines, manual DI to a container).
- **UI paradigm** — same screen, different rendering model (e.g. View to Compose, UIKit to
  SwiftUI).
- **Module type** — same code, different packaging or target (e.g. Android module to Kotlin
  Multiplatform module).

## Borderline

- **Major version bump with breaking API** — IN if the migration is confined to adapting call
  sites to the new API surface; the moment the bump also changes the runtime contract (a schema, a
  wire format) it inherits the OUT classification for that part.
- **Language-within-platform** — IN only when the three-condition test below holds in full.
- **Localized pattern replacement** — replacing one recurring idiom (a singleton pattern, a
  callback wrapper) across a codebase is IN; it is a localized migration by volume even though it
  touches many files, because each site is independent and none crosses a topology boundary (see
  `## Localized vs cross-cutting`).

### Language-within-platform

A migration that changes the implementation language while staying on the same platform (e.g. Java
to Kotlin, Objective-C to Swift) is IN only when all three conditions hold. Any one missing moves it
to OUT — it has become a platform or runtime port, not an in-project code migration.

1. **Same runtime/target.** The migrated code still executes on the same runtime or compilation
   target as before (the same JVM, the same Apple runtime); the language changes, the execution
   substrate does not.
2. **Bidirectional interop.** Code in the old language can call code in the new language and vice
   versa without a translation layer, for the whole duration of the migration.
3. **Per-file coexistence.** Individual files can be converted one at a time and the build stays
   green in between; the migration does not require an atomic whole-module cutover.

## OUT

Each OUT type is out because the boundary itself, not the technology inside it, changes:

- **Full language or framework port of an entire application** — the whole system is rewritten,
  there is no surviving reference to hold behavior parity against at the module level.
- **Platform migration** — moving the deployment target (e.g. mobile to web) changes the
  observable surface itself; there is no "externally observable behavior" left constant to defend.
- **Protocol migration** — the wire contract with external parties changes; correctness is defined
  by an external spec this skill has no authority over.
- **Schema migration** — the same reasoning as protocol: a persisted data contract change is a
  data-migration problem, not a behavior-preserving code migration.
- **Build/config-only work** — Groovy to Kotlin DSL, CI pipeline changes, toolchain bumps touch no
  runtime behavior at all, so there is nothing for a judge to verify.

Build changes that **accompany** a code migration remain IN: a version-catalog edit needed because a
library swap changed its coordinates, or a source-set reorganization needed because a module became
multiplatform, is scoped to the code migration that requires it, not a migration in its own right.

## Localized vs cross-cutting

The unit of work, not the file count, decides which topology a migration has.

**Localized** — each site can be translated and verified independently of every other site. A
thousand call sites of a deprecated string-formatting utility are still localized: swapping one does
not change what any other site observes.

**Cross-cutting** — the unit of work is an aspect of the dependency graph or a shared layer, not a
file. Signals that a migration is cross-cutting rather than large-but-localized:

- Two implementations of the aspect must **coexist** during the migration (two DI containers, two
  logging backends), and their coexistence changes resolution or ordering semantics that neither
  implementation has on its own.
- A site's correctness depends on **which graph or layer configuration is active**, not just on its
  own contents — a callback's behavior changes depending on which threading model wraps it.
- The compiler is blind to the failure mode: a broken injection graph, a broken dispatcher swap, or
  a broken logging pipeline compiles cleanly and fails only at runtime.
- Verification requires observing an aspect end to end (a full resolution graph, a full trace), not
  a single translated file.

Misclassifying a cross-cutting migration as localized is the most expensive mistake available: it
silently invalidates the judge, because a per-file check cannot see a graph-level regression.
Cross-cutting mechanics, the interop-bridge pattern, and the DI worked example live in
`[[cross-cutting]]`.

## STOP conditions

Two conditions, both normative here; `SKILL.md` § Red Flags / STOP reflects them without
redefining them.

1. **No valid judge is reachable at any level of the verification matrix, and no safety net can be
   built.** INV-3 does not assume a judge always exists. If every level in
   `[[verification-matrix]]` fails to distinguish correct from incorrect for this migration, and
   none of the three safety-net entry branches in `[[safety-net]]` produces one, the migration does
   not start. Proceeding anyway would produce an unfalsifiable "behavior preserved" claim, which
   is worse than not migrating: it ships a defect under a certificate of correctness. This is a
   NO-GO to report, not an obstacle to engineer around.

2. **Interruption mid-migration is a normal outcome, not a failure.** A partially migrated tree is
   a legitimate resting state, not damage, because the work queue is resumable by reconstruction,
   port markers record what is unfinished, and an interop bridge (where one is in use) leaves both
   implementations live and working. The condition on "normal": **stopping is only legitimate on a
   green build.** A partially migrated tree that compiles and passes its existing tests may be left
   as-is between sessions; a partially migrated tree that does not build is not a resting state, it
   is breakage, and work does not stop there.

## Coverage authoring: automated vs manual

**Coverage assessment: IN. Test code authoring: OUT.** Evaluating what the judge can see, ranking
coverage gaps by risk, and stating what a test must prove belong to this skill's Phase 0 output.
Writing the test bodies themselves does not — it is handed off to `test-authoring-role` as a
coverage-gap handoff report (schema in `[[safety-net]]`).

The runtime boundary of that handoff is not uniform across stacks. Where `test-authoring-role` is
filled by an automated tool (Kotlin, Swift are the stacks with one available today, e.g. a
characterization-mode test-writing skill), authoring can be delegated and run unattended. Outside
those stacks (TypeScript, Python, Go, and others) the role is filled **manually** — a human writes
the test bodies from the handoff report. This is a degraded mode, not an unsupported one: the
report's `baseline` field exists specifically so a manual author has a description of the behavior
to capture rather than a bare target with no specification.

## Serialization

Byte-for-byte format compatibility, when the migration touches a serialization boundary, is a
**separate acceptance criterion** from "the existing tests are green." Existing tests were written
against the outgoing serializer and typically assert on decoded values, not on the wire bytes; they
can pass while the produced bytes differ (field order, discriminator encoding, numeric width). A
migration that changes a persisted or transmitted format must state and check byte-for-byte
compatibility explicitly in Phase 6, not infer it from green tests.
