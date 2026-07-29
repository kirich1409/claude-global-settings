# Phase 0: Analysis

Phase 0 runs before any file is touched. It produces nine outputs, in a fixed order, and ends
with a proposed execution mode that a human confirms or overrides. Nothing in Phase 1 onward is
scheduled until this phase is complete.

## Procedure

Work through the outputs in order; each later output depends on at least one earlier one.

1. Read the target code and classify the migration against the taxonomy in `scope.md` — this
   fixes what "in scope" means for everything that follows.
2. Map the topology: is the change contained to one module boundary (localized), or does it cross
   a graph or a shared layer (cross-cutting)? Topology decides whether the judge can be
   compile-time or must be a runtime one — see `cross-cutting.md` for the graph case.
3. Build the verification matrix for this specific migration using the level definitions in
   `verification-matrix.md`, and pick the minimum level that can actually distinguish correct
   from incorrect here.
4. Run the judge coverage assessment: how much of the surface the chosen judge actually watches,
   measured on the code as it stands today. Procedure and instrumentation: `judge.md` §
   Judge coverage assessment.
5. Build the test coupling inventory: which existing tests are agnostic to the outgoing
   technology and which are welded to it. This is a distinct output from the coverage assessment
   above — one measures how much is watched, the other measures how portable the watching is.
   Procedure: `judge.md` § Test coupling inventory.
6. Assess risk: blast radius (how much breaks if a rule is wrong), volume (how many sites), and
   known hazards specific to this migration (for example, a serialization format that must match
   byte-for-byte, or a DI graph whose resolution order the compiler cannot check).
7. Detect a legacy profile: the changed surface has no usable judge — no tests reach it, or
   output 5 classified every test that covers it as coupled to the outgoing technology — or the
   project has no regression pass before release. A legacy profile does not block the migration;
   it changes which judge branch applies — see `safety-net.md`.
8. Propose an execution mode to the human, using the risk-versus-verification-cost reasoning
   below.
9. Record the safety-net decision: whether a judge is already reachable, or one of the three
   entry branches in `safety-net.md` must run first, or — in the worst case — no branch produces
   a valid judge and the migration is a NO-GO.

## Phase 0 outputs

1. Migration type.
2. Topology.
3. Verification matrix.
4. Judge coverage assessment.
5. Test coupling inventory.
6. Risk assessment.
7. Legacy-profile detection.
8. Proposed execution mode.
9. Safety-net decision.

Outputs 4 and 5 stay separate. Coverage assessment answers "how much does the judge see"; coupling
inventory answers "how tied to the outgoing technology are the tests that provide that coverage".
A migration can score well on one and badly on the other — high coverage from tests that assert on
the library being replaced is not evidence the migration is safe, it is evidence the judge will
need rewriting mid-flight.

## Output details

### Migration type and topology (outputs 1-2)

Owned by `scope.md` and `cross-cutting.md` respectively. Phase 0 applies the taxonomy; it does not
redefine it. Misclassifying topology is the most expensive mistake available here, because it
silently invalidates whatever judge gets picked next — a cross-cutting change judged as if it were
localized looks green on tests that never exercised the shared graph.

### Verification matrix (output 3)

Owned by `verification-matrix.md`. The matrix names, for this migration specifically, whether the
compiler is a referee, whether existing tests are sufficient, whether a runtime check is required,
and the minimum judge level that clears the bar. Re-derive it per migration; do not reuse a matrix
from a previous one even on the same stack.

### Judge coverage assessment and test coupling inventory (outputs 4-5)

Owned by `judge.md`. Both are measured on the code as it exists before any translation starts, not
projected forward. A coverage number measured after translation has already begun tells you
nothing about the risk you were carrying when you started.

### Risk assessment (output 6)

Blast radius, volume, and hazards specific to the migration. Blast radius is what a wrong RULEBOOK
rule corrupts, not what a wrong translation in a single file corrupts — a rule error propagates to
every site the rule touches. Volume is the size of the work queue once the dependency map exists.
Hazards are the recurring cases where a green build understates the actual risk: a byte-level
format that must round-trip identically, or a runtime dependency graph that compiles cleanly while
broken.

### Legacy-profile detection (output 7)

A binary check with three independent triggers, each sufficient on its own: the changed surface has
no tests reaching it, or every test that does reach it was classified coupled in output 5, or the
project ships without a regression pass before release. Any trigger routes to `safety-net.md`
before Phase 1 starts, because Phase 1 assumes a reachable judge exists.

The middle trigger is why output 7 reads output 5 rather than counting test files. A surface whose
coverage is entirely coupled to the outgoing technology has, in `judge.md` § Test coupling
inventory's words, no judge at all: the suite dies with the technology it asserts on, and rewriting
its assertions to compile against the new code destroys exactly the stability that made it a judge.
Tests existing is not the condition; a judge surviving the migration is. Read the trigger as "no
usable judge on the changed surface", and a fully coupled suite satisfies it as surely as an empty
one.

### Safety-net decision (output 9)

Owned by `safety-net.md`. Three possible outcomes: a judge is already reachable and no safety net
is needed; one of the three entry branches runs first; or no branch produces a valid judge, which
is a NO-GO — see the STOP conditions owned by `scope.md`.

## Mode selection: risk versus verification cost

The proposed mode is a function of two independent axes, not a single risk score:

- **Risk** — what output 6 measured: blast radius, volume, and hazards. A localized swap of a
  small library touched by a handful of call sites is low risk regardless of how it is verified. A
  cross-cutting DI container swap is high risk by construction, because it changes resolution and
  singleton semantics everywhere the container is used.
- **Verification cost** — what outputs 3-5 measured: how expensive it is to run the chosen judge.
  A judge that is a command anyone can issue and that returns in seconds or minutes — compiler,
  existing suite, a recorded baseline diffed automatically — is cheap. A judge that cannot produce
  a verdict without a system driven end to end, a device, a provisioned environment or a human
  observing the result is expensive, independent of how risky the underlying change is.

  **Cost is what it takes to run the judge, not the label of the level it sits at.** The two come
  apart in both directions and the level label is the wrong input here: an L3 golden-master diff
  that is a recorded payload and one assertion runs in the same second as the unit tests, while an
  L2 reachable only by a person working through a suite by hand is expensive. Read this axis by
  the run.

Combining the two axes gives the proposed mode:

- **Cheap verification, low risk** (the judge runs unattended on one command in seconds to
  minutes, *and* output 6 came back low risk — small blast radius, bounded volume) → propose
  **autonomous**: the loop runs
  through Phase 6 without a human checkpoint between phases, because a wrong result is caught
  cheaply and immediately by the judge itself. The minimum valid level does not gate this corner:
  an L3 judge that runs in one command is cheap verification and belongs here.
- **Expensive verification, high risk** (no verdict without a human in the observation loop, a
  device or a provisioned environment, *and* output 6 came back high risk) → propose
  **human-gated**: a human reviews the RULEBOOK before fan-out and reviews
  Phase 6 results before the migration is considered done, because a wrong result here is
  expensive to detect and expensive to undo.
- Everything between the two — cheap-verification-high-risk, or expensive-verification-low-risk,
  or moderate on both axes (a judge that needs some orchestration but no human observer, over a
  change whose radius is real but bounded), or anything that does not clearly sit at either corner
  — proposes **adaptive**, the default: run the loop end to end but surface each phase's result
  for a light-touch confirmation rather than a full review, escalating to a checkpoint only where
  output 6 or output 9 flagged a hazard.

**Two axes, and nothing else, select the mode.** Each corner is a conjunction of both axes, so no
input matches more than one bullet, and everything that matches neither corner falls to adaptive.
Topology and the legacy profile are inputs to the axes, not a third gate: cross-cutting topology is
what makes risk high by construction (Risk axis above), and a legacy profile is expensive
verification exactly when its judge needs a human in the observation loop. A cross-cutting migration
whose judge is one unattended command is therefore high risk with cheap verification — adaptive,
with the escalations output 6 and output 9 ask for. Reading topology as a direct human-gated trigger
is an error.

**The proposal is not the decision.** Phase 0 names a mode and states the reasoning that produced
it; the human confirms, downgrades, or upgrades it before Phase 1 starts. A cheap-and-low-risk
proposal that the human wants reviewed anyway is a valid outcome, and so is a human choosing to
run a nominally high-risk migration autonomously because the codebase is disposable. The function
above produces a recommendation, not an authorization.

## References

- Taxonomy and topology definitions: [scope.md](scope.md)
- Verification levels and minimum-valid-level procedure: [verification-matrix.md](verification-matrix.md)
- Judge sources, coverage assessment, coupling inventory: [judge.md](judge.md)
- Safety-net entry branches and the NO-GO condition: [safety-net.md](safety-net.md)
