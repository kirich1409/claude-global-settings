# Migration loop: phases 1-6

Phase 0 decided *whether* and *how much*. This file owns *how* — the mechanics of phases 1 through
6: what each phase consumes, which role executes it, what artifact it leaves behind, and the exit
criterion that must hold before the next phase starts.

Two mechanisms the loop leans on are documented elsewhere and are not restated here: the dependency
map and the work queue ([depmap-and-queue.md](depmap-and-queue.md)), and the review protocol
([adversarial-review.md](adversarial-review.md)).

The phases are a pipeline, but the loop is a cycle: phases 3 through 6 run per batch, and a finding
from any of them routes back into the RULEBOOK between batches — never into a patch of the file
where it surfaced.

## Phase 1

**Produces:** RULEBOOK, gap inventory, dependency map. **Executed by:** `rule-author-role`.

The one pass over the migration surface that builds all three artifacts at once. Read every site in
scope, and for each construct that repeats, write a rule that says what it becomes. A rule that
covers one site is not a rule; fold it into the gap inventory instead, as a site to be handled by
hand. The gap inventory carries one row per site that cannot be translated mechanically, so that
"not covered by a rule" is a recorded state rather than a surprise discovered in Phase 3.

The dependency map comes out of the same pass, because the pass already touches every file and its
imports. Build it as a deterministic topological order, cycles taken as single units — mechanics in
[depmap-and-queue.md](depmap-and-queue.md).

**Exit criterion:** every construct in the migration surface is either covered by a RULEBOOK rule or
listed as a gap-inventory row. An unclassified construct means Phase 1 is not finished, and starting
Phase 2 on an incomplete rulebook stress-tests nothing.

## Phase 2

**Produces:** an amended RULEBOOK and, usually, the batch of translated sample files.
**Executed by:** `implementer-role` translating, `rule-author-role` amending.

Pick a small representative sample — three to five sites — and translate them against the RULEBOOK
as written. The sample is chosen for awkwardness, not for convenience: the file with the deepest
nesting, the one with the generic signature nobody understands, the one whose test is welded to the
outgoing library. A rule that has only met the easy case is a guess dressed as a decision.

Findings route into the RULEBOOK, not into the sample files. If a sample needs a hand-edit that no
rule predicts, that is the finding: either a new rule or a new gap-inventory row.

**Exit criterion:** the sample translates with no unrecorded improvisation, and the resulting sample
compiles. Two consecutive stress-test rounds that each produce new systematic rules mean the rulebook
is still being discovered — run another round rather than fanning out on rules that are still
churning.

## Phase 3

**Produces:** translated target files, new gap-inventory rows, port markers.
**Executed by:** `implementer-role` in fan-out, then `adversarial-reviewer-role` and `fixer-role`.

Fan out over the work queue in dependency order. Every worker gets the same three things: the
RULEBOOK, its assigned unit of work, and the instruction that the RULEBOOK is **read-only** for the
duration of the batch. A worker that hits a construct the RULEBOOK does not cover writes a port
marker and a gap-inventory row; it does not invent a rule, because a rule invented inside one
worker's context is invisible to the other workers translating the same construct differently at
the same time.

Batch size is bounded by how much divergence you are willing to re-run: a wrong rule corrupts every
file the batch touched, so the batch is the unit of loss. Wait for the batch to finish by polling a
real completion signal with an upper bound, never by sleeping a guessed interval — the shape is in
[depmap-and-queue.md](depmap-and-queue.md) § Waiting on the queue.

Then review. Two reviewers in separate contexts, an arbiter on disagreement, and every finding
citing a specific rule: [adversarial-review.md](adversarial-review.md). Accepted findings split in
two directions — a rule that was applied wrongly goes to `fixer-role`, which reapplies the existing
rule to the affected sites; a rule that was itself wrong goes to `rule-author-role`, and the
amendment lands **between** batches, after which the affected sites are re-translated rather than
patched.

**Exit criterion:** the work queue is empty for this batch — every target file exists on disk — and
every review finding has been routed to a fix, a rule amendment, or an explicit gap-inventory row.

## Phase 4

**Produces:** a compiling tree. **Executed by:** `implementer-role`, findings to `rule-author-role`.

Compile. A compile error is diagnosed as a rule defect first and a file defect second: if the same
error class appears in more than one file, it is a rule defect by definition and the fix belongs in
the RULEBOOK. Only a genuinely one-off error — a site the gap inventory already flagged — gets a
hand-fix.

Where this phase sits relative to the loop is a decision, not a constant: see
`## Compile placement`.

**Exit criterion:** the tree compiles with no errors attributable to the migration, and every error
class that appeared more than once has a corresponding RULEBOOK amendment recorded.

## Phase 5

**Produces:** evidence that the system still starts and runs its main path.
**Executed by:** `implementer-role`.

Smoke is the narrowest run that would notice a catastrophic break: the application starts, the
migrated path executes once, no initialization blows up. It is deliberately cheap and deliberately
early, and it exists to catch the failures the compiler structurally cannot see — an empty
dependency graph resolves at startup, not at compile time.

**Targets with no entry point.** A library, an SDK, a Gradle or package module with nothing to start
still has a Phase 5; what changes is what counts as the run. Smoke there is the narrowest execution
of the migrated path from outside the migrated code — construct the public entry point once and call
it once, from a test, a script or a REPL, checking only that it runs and returns rather than what it
returns. Where the cheapest such execution is the first invocation of the Phase 6 judge, Phase 5
**collapses into it**: record it as collapsed, naming the run and what it observed. Collapsed is not
skipped — the exit criterion below still has to be met, and Phase 5 is not on the
`## Lightweight path` skip list at any size.

Smoke passing is not behavior parity. It proves the system is alive, not that it behaves the same.
Treating a green smoke run as the end of the migration is the most common quiet downgrade of Phase
6.

**Exit criterion:** the main path executes end to end at least once without an error that the
migration introduced.

## Phase 6

**Produces:** the behavior-parity verdict. **Executed by:** `scenario-judge-role` where the judge is
a runtime one, otherwise by whatever runs the existing test suite.

Run the judge Phase 0 chose, at the minimum valid level it named. This is the phase that discharges
the behavior-preserving claim, and it is the only phase whose result can turn the migration down.

Two rules keep it honest:

- **The judge is the one Phase 0 named**, not a cheaper one discovered to be convenient now that the
  code is written. Downgrading the judge at the end is choosing the verdict before the evidence.
- **Criteria that do not follow from tests passing are stated separately.** Byte-for-byte
  serialization compatibility is the recurring case: existing tests assert on decoded values, so
  they pass while the wire bytes differ. Each such criterion is its own acceptance line with its own
  check.

Open port markers are Phase 6 input, not leftovers: a target file that exists but carries a
`TODO(port)` marker is an open item, and the parity verdict states which markers remain and why they
are acceptable.

**Exit criterion:** the judge reports parity at the named level, every separately-stated criterion
has been checked, and the remaining port markers are enumerated with a disposition each.

## Compile placement

Compilation is a decision about placement, and it has a default and one named exception.

**Default: compilation sits outside the translation loop.** Translate the batch, then compile once.
A full build is expensive — on most stacks it dominates the cost of the translation itself — and a
per-file build multiplies that cost by the number of sites while adding almost nothing: a rule
defect shows up in the batch compile just as clearly as in the per-file one, and it is fixed the
same way either way, by amending the rule and re-translating.

**Exception: compilation moves inside the loop when an incremental typecheck is cheap.** Some stacks
offer a fast, file-scoped typecheck that returns in the time a translation takes — an incremental
compiler daemon, a language server diagnostic, a standalone type checker over a single module. Where
that exists, running it per file shortens the feedback loop from "one batch" to "one file", which
matters most exactly when the rules are least trusted: early batches, unfamiliar stacks, migrations
whose rules were amended in the last round.

Deciding between them:

1. Measure one typecheck of one file on this stack. If it is comparable to the cost of translating
   that file, the exception applies; if it is a full build, the default holds.
2. Weigh batch size. A large batch with cheap typecheck is the strongest case for the exception,
   because the batch is the unit of loss and per-file checking shrinks it.
3. Weigh rule maturity. Rules that survived Phase 2 and several clean batches earn the default;
   freshly amended rules earn the exception for the batch that first exercises them.

The decision is recorded in the RULEBOOK alongside the rules, because it is part of how the loop
runs, and a later batch should not silently change it.

## Lightweight path

A three-file dependency swap does not pay for the machinery a thousand-site graph rewrite needs.
INV-5 makes the reduction explicit rather than leaving it to be improvised: below the thresholds
listed here, the loop drops the following mechanisms.

skip:

- Work queue — the site list fits in one message; a queue that is re-derived from disk buys
  resumability nobody needs when the whole batch takes one pass.
- Dependency map — with a handful of files the ordering is either obvious or irrelevant, and a
  topological sort over four nodes is ceremony.
- Phase 2 stress-test round — the whole migration is smaller than a normal stress-test sample, so
  the first translation *is* the stress test; a rule defect surfaces immediately in Phase 4.
- Adversarial review with two reviewers and an arbiter — a single reviewing pass replaces it, still
  citing rules for its findings.
- Batching in Phase 3 — the migration is one batch, so the between-batch amendment cycle collapses
  into a single translate-review-fix pass.

The skips are legitimate only when **all** of the following hold. Any one missing pulls the full
loop back:

1. Topology is localized. Cross-cutting migrations skip nothing — the compiler is not a referee for
   them, and the machinery being skipped is exactly what catches graph-level regressions.
2. The site count is small enough to hold in one context — as a rule of thumb, under roughly ten
   files, and small enough that a single reviewer can read the whole diff.
3. A judge already exists at the minimum valid level Phase 0 named. If the safety-net step had to
   run, the migration is not small in the sense that matters.
4. Blast radius is bounded: no rule in play touches more sites than the migration itself contains,
   and no persisted or transmitted format changes.
5. Fan-out is not needed — one worker can do the whole translation, so there is nobody to keep
   consistent with anybody else.

What is never skipped, at any size: Phase 0, a named judge, Phase 6 against that judge, and the
rule that a systematic finding fixes the rule rather than the file.

## Loop health signals

These are **operational signals that the loop is running badly**, not STOP conditions. The STOP
conditions are exactly two and are owned by [scope.md](scope.md); nothing here authorizes abandoning
a migration. What these signals authorize is pausing fan-out and repairing the rules before spending
another batch.

- **The same finding keeps recurring.** A defect that review catches again in the next batch means
  the previous round fixed instances instead of the rule that produced them. Stop translating and
  find the rule; if there is no rule to fix, the missing rule is the finding.
- **RULEBOOK amendments per batch are rising rather than falling.** A healthy loop converges: batch
  one produces many amendments, batch four produces few. A rising count means the rules are being
  discovered from the code rather than derived from the migration, and each new batch is buying
  amendments at the price of a full translate-review cycle. Return to Phase 2 with a harder sample.
- **The share of `TODO(port)` markers is growing.** Markers are meant to be a bounded tail of
  genuinely irregular sites. A growing proportion means the RULEBOOK is losing coverage of the
  surface — workers are deferring rather than translating, and the migration is quietly turning into
  a gap inventory with some files attached. Measure the ratio each batch; if it climbs twice in a
  row, the next unit of work is a rulebook round, not a translation batch.

All three have the same remedy and the same failure mode. The remedy is to fix the loop. The failure
mode is to keep fanning out because the batches are individually succeeding — each one green, the
whole trending worse.

## Worked examples

### Worked example: three-file serializer swap

A small module reads and writes one persisted format through a JSON library that is being replaced.
Three files: two annotated model classes and one parser, plus one existing test.

Phase 0 classifies it: library to library (IN), localized topology, judge = the existing test suite
plus a separate byte-for-byte format check, risk low, mode autonomous, no safety net needed. The
mode follows from the run cost of that judge — one test command, seconds, unattended — over a
localized change with a small blast radius; the minimum valid level being L3 rather than L2 does not
move it, because the axis is what the judge costs to run, not the label on the level. The site
count and the localized topology satisfy the `## Lightweight path` conditions, so the run skips the
work queue, the dependency map, the Phase 2 round, and the two-reviewer protocol.

What actually runs: the rules are written down first — annotation X becomes annotation Y, the
nullable-field convention becomes an explicit default, the custom adapter becomes a custom
serializer — then all three files are translated in one pass, one reviewer reads the whole diff
against those rules, the module compiles, the existing test suite runs, and the byte-parity check
serializes a fixed set of fixtures with the old and new implementations and compares the output
bytes.

The byte-parity check is the part that is not optional. The existing tests decode and assert on
values, so they stay green even if field order or number formatting changed on the wire — exactly
the failure a persisted format cannot absorb. Phase 0 named this check as a separate criterion, and
the lightweight path drops machinery, never the judge.

### Worked example: HTTP client swap across a Python service

A service makes outbound calls through one HTTP client library and is moving to another with a
different session and timeout model. Roughly sixty call sites across eleven modules, plus a shared
client-construction module that most of them import.

Phase 0 classifies it: library to library (IN), localized by unit of work despite the file count —
each call site can be translated and verified independently — with one exception, the shared
construction module, which is a genuine shared layer and is migrated first, alone. The judge is the
existing test suite (the service has one, with mocked transport) plus a runtime check on retry and
timeout behavior, because those live in the client's configuration rather than in the call sites and
no test asserts on them today. Verification cost is moderate, risk is moderate, mode is adaptive.

The full loop applies. Phase 1 writes rules for the recurring shapes — session construction, the
timeout parameter that changed name and unit, response-body access, the exception hierarchy the
`except` clauses catch — and a dependency map that puts the shared construction module ahead of
everything importing it. Phase 2 stress-tests on the three ugliest sites: one that streams a
response, one that reuses a session across calls, one whose test patches the client's internals
directly. The third one produces both a rule and a gap-inventory row, because the test is coupled to
the outgoing library and has to be rewritten before it can judge anything.

Phase 3 fans out in dependency order, batches of about a dozen sites, RULEBOOK read-only inside each
batch. Two amendments land between batch one and batch two — one on how the timeout unit converts,
one on an exception type nobody mapped — and the affected sites are re-translated rather than
patched. Phase 4 takes the named exception at first: this stack has no build step worth the name,
and the type checker over the whole package returns in seconds, so it runs per file for the first
two batches while the rules are still being amended. Once the amendments stop, the checking moves
back outside the loop — the default placement — and runs once per batch.

Phase 5 starts the service and issues one outbound call. Phase 6 runs the existing suite and then
the retry/timeout scenario check against a stub server that fails the first attempt — the check that
exists because Phase 0 noticed the compiler and the test suite were both blind to it. Two
`TODO(port)` markers remain on a deprecated endpoint scheduled for deletion; the parity verdict
names them and their disposition.

## References

- Dependency map, work queue, waiting on a real signal: [depmap-and-queue.md](depmap-and-queue.md)
- Review protocol, rule citation, arbiter: [adversarial-review.md](adversarial-review.md)
- Scope taxonomy and the two STOP conditions: [scope.md](scope.md)
- RULEBOOK, gap inventory, port markers: [rulebook.md](rulebook.md)
- Phase 0 outputs and mode selection: [phase-0-analysis.md](phase-0-analysis.md)
