# Verification matrix

Every migration makes one claim: **externally observable behavior did not change.** The matrix is
how that claim is priced. It names six levels of evidence, defined here in migration terms, and a
procedure for picking the lowest level that can actually tell a correct port from a broken one.

The levels below are defined in this file and nowhere else. They are not a general testing ladder
borrowed from elsewhere: each level is stated as *what it proves about behavior preservation*,
which is a narrower and more useful question than "how good is this test".

Related, not repeated here: the taxonomy that classifies a migration is in `scope.md`; how a judge
is chosen and where its evidence comes from is in `judge.md`; topology and dependency-graph
specifics are in `cross-cutting.md`.

## L0

**Proves:** the ported code is well-formed — it compiles, links, and passes the static gates the
project already enforces. Green build is L0.

**Says nothing about:** behavior. A migration that compiles has cleared the lowest bar available;
for most migrations L0 is a precondition for evidence, not evidence.

**Cost:** whatever a build already costs. Always run it; never report it as parity.

## L1

**Proves:** the port has the shape the RULEBOOK says it should have. Structural evidence obtained
without executing anything: no occurrences of the outgoing API remain, signatures and nullability
match the mapping, no port marker is left unaccounted for, public surface diff is empty or
explained, lint rules specific to the target technology pass.

**Says nothing about:** whether the mapped constructs mean the same thing at runtime. L1 catches a
rule applied inconsistently; it cannot catch a rule that is wrong.

**Cost:** cheap and scriptable. This is the level that scales across thousands of sites, and the
level where "the rules are the artifact" pays off — an L1 failure is almost always a rulebook
defect, not a file defect.

## L2

**Proves:** behavior is preserved *to the exact extent the existing test suite was watching it*.
The pre-existing tests, unmodified, still pass against the ported code.

**The caveat that makes or breaks this level:** the suite's reach is not assumed, it is measured —
the judge coverage assessment in `judge.md` establishes how much of the migrated surface the suite
observes, and the test coupling inventory establishes how much of the suite is welded to the
outgoing technology. A suite that had to be rewritten to compile against the new API is no longer
an independent referee at L2; it has become part of the change under test.

**Cost:** near zero when the suite exists and is agnostic. This is the most common minimum valid
level for localized migrations, and the most commonly overstated one.

## L3

**Proves:** parity on an observable surface that the existing suite did not cover, using evidence
built for this migration. Three usual forms:

- characterization tests captured against the old implementation before the port;
- golden master — outputs recorded from the old code and compared byte-for-byte or field-by-field
  against the new;
- differential execution — old and new implementations run against the same inputs and their
  outputs compared directly.

**Says nothing about:** composition. L3 exercises units and formats, not the assembled system.

**Cost:** authoring effort, paid before the migration starts. When it is needed and the coverage
does not exist, the migration pauses to build it — the branches and the handoff are in
`safety-net.md`.

## L4

**Proves:** the assembled system still behaves. The application or service actually starts with its
real wiring, the main paths execute, screens render, requests are served, and the observed results
match the pre-migration behavior on the same inputs.

**This is the first level at which whole classes of migration defect become visible at all:**
dependency graphs that resolve to the wrong instance, lifetime and singleton semantics that
silently changed, reflection and resource lookup that fail only when reached, ordering and threading
differences, format negotiation between two components that were ported separately. Every one of
these compiles cleanly and can pass unit tests.

**Cost:** an environment, fixtures, and time. Non-negotiable when the migration touches composition
rather than leaves.

## L5

**Proves:** parity on the real input distribution — evidence from production or a production-like
population: staged exposure, comparison of error and performance signals against a pre-migration
baseline, or shadow traffic where both implementations run and their outputs are compared.

**Its honest status:** L5 is the only level that sees inputs nobody thought to write down, and the
only level that detects failures *after* users do. It compensates for missing lower-level evidence;
it does not replace it, and a migration plan that names L5 as its judge is naming a monitoring plan.
The compensation view is developed in `safety-net.md`.

**Cost:** release machinery plus exposure to real failure. Justified when the population itself is
the specification.

## The compiler is a referee only for some migrations

There is no fixed answer to "does the type system catch this". The compiler's power as a referee is
a property of the *migration*, not of the language:

- It is a strong referee when the mapping is expressed in types the compiler checks and every
  incorrect mapping is ill-typed — a renamed API, a utility library swap, a data class moved between
  packages. Here L0 plus L1 genuinely discharges most of the claim.
- It is a weak referee when the new technology accepts a wider set of programs than the old one: the
  broken version is still well-typed, so nothing fails until execution. Runtime-resolved dependency
  graphs are the standard example — a container swap with a missing or mis-scoped binding compiles
  perfectly and fails at resolution time.
- It is blind by construction when the contract is a value, not a type: byte-level formats, wire
  payloads, string keys, generated identifiers, ordering, timing. The types are unchanged; the
  bytes are not.

Practical consequence: decide what the compiler can and cannot see **before** choosing the level,
and write that decision down. "The build is green" is a claim about L0 that gets quoted as if it
were a claim about behavior, and that substitution is the single most common way a migration ships
a regression.

## Choosing the minimum valid level

Pick the **lowest level that can distinguish a correct port from an incorrect one for this specific
migration**. Not the highest reachable, not the cheapest available — the lowest that is *valid*.
Higher is waste; lower is an unfalsifiable claim.

Procedure, per migration (or per distinct group of sites, when one migration contains several):

1. **Name the failure modes.** What could this technology swap plausibly break? Be concrete:
   wrong overload, lost null-handling, changed default, altered lifetime, reordered output,
   different encoding, dropped side effect.
2. **Ask of each: at what level does this become visible?** Walk L0 upward and stop at the first
   level that would surface it. A failure mode nothing surfaces is a coverage gap, not a level.
3. **Take the maximum over the failure modes.** The migration's level is the highest of the per-mode
   levels — one runtime-only failure mode pulls the whole group to L4 regardless of how much L2
   evidence exists elsewhere.
4. **Check reachability.** Can that level actually be run here today? If not, either build the
   evidence (`safety-net.md`) or, if no branch produces a valid judge at any level, this is a NO-GO
   and the migration does not start (`scope.md`).
5. **Record it as an acceptance criterion, per criterion.** Some criteria do not follow from the
   others and must be stated separately — byte-for-byte format compatibility is the recurring one.
   "Tests are green" never implies "the format is unchanged".
6. **Re-run the procedure when the port changes shape.** A migration that grows from leaves into
   composition has changed its topology, and topology drives the level.

Two anti-patterns worth naming, because both look like diligence:

- **Level inflation** — demanding L4 for a rename, which spends the migration's budget on ceremony
  and starves the parts that need it.
- **Level laundering** — declaring L2 because a suite exists, without measuring what it covers or
  whether it survived the port unmodified. See the coupling inventory in `judge.md`.

## Example matrix

Rows are illustrative shapes, not an exhaustive list. Read them as worked applications of the
procedure above.

| Migration | Caught by compilation | Existing tests sufficient | Runtime needed | Minimum valid judge |
|---|---|---|---|---|
| Utility library swap with a like-for-like API (pure functions, no reflection) | Yes — every incorrect mapping is ill-typed | Yes, if they are agnostic to the outgoing library | No | L1: build plus a static sweep that no outgoing symbol remains |
| Serialization library swap (annotation-driven model to a different engine) | Partially — signatures only; field names, defaults, and encoding are values, not types | No — suites usually assert on objects, never on the emitted payload | No, but a harness must produce output | L3: golden-master byte-for-byte comparison of payloads produced by the old code |
| Runtime dependency-injection container swap | No — a missing or mis-scoped binding is well-typed; the compiler does not catch a broken graph | No — unit tests construct their own objects and never touch the real graph | Yes — resolution happens at startup | L4: real startup with the production wiring, plus explicit lifetime and scope assertions; see `cross-cutting.md` |
| HTTP client swap in a service, `requests` to `httpx` | No — a dynamically typed client swap is invisible to static checks | Rarely — tests usually stub the client itself and are welded to its shape | Yes — timeouts, redirects, connection reuse, and error mapping only appear when a request is made | L3 rising to L4: recorded request/response pairs replayed against a stub server, then one end-to-end call per integration |
| Imperative UI to a declarative UI paradigm | Partially — the widget tree type-checks while rendering the wrong thing | No — view-layer assertions are the most coupled category there is | Yes — layout and state are runtime products | L4: rendered-output comparison plus interaction parity on the migrated surface |
| Callback or thread-based concurrency to a structured async model | Barely — signature changes are checked; ordering, cancellation, and thread affinity are not | No — timing and ordering are exactly what unit tests are written to avoid depending on | Yes | L4: parity on ordering, cancellation, and error propagation under a realistic execution schedule |
| Reactive stream library to a fine-grained reactivity primitive, RxJS to signals | No — subscription lifetime and glitch behavior are not type-level properties | No — stream tests assert emission sequences of the outgoing library and are single-use | Yes — scheduling differences are observable only when running | L4: emission and update-order parity, plus a leak check that disposals still happen |

Reading the table: the first row is the only one where compilation is the referee, and it is the
only row that stays at L1. Every other row moves up for a different reason — values the type system
does not see, wiring resolved at runtime, or ordering that no static check models.
