# The judge

"Behavior preserved" is a claim, and a claim without a referee is decoration. The judge is whatever
mechanism can distinguish a correct migration from an incorrect one for *this* migration. Phase 0
names it before any code moves, and names it concretely enough that someone else could run it.

This file owns three Phase 0 concerns:

- where a judge comes from (three sources, in order of preference);
- **judge coverage assessment** — Phase 0 output 4, how much of the migrated surface the judge
  actually watches;
- **test coupling inventory** — Phase 0 output 5, how much of the existing suite dies with the
  outgoing technology.

Outputs 4 and 5 are separate and stay separate. A suite can watch 90% of the migration surface and
still be worthless as a judge because every assertion is written against the API being removed.

The *strength* a judge must have is not decided here: it comes from the minimum valid level in
`[[verification-matrix]]`. This file decides where a judge of that strength comes from and whether
the one you have qualifies. If no source produces a valid judge at any level and no safety net can
be built, that is a NO-GO — the condition is normative in `[[scope]]` § STOP conditions.

## Three judge sources

Preference order. Each step down costs more to build, so stop at the first source that reaches the
required level — per surface, which is not always the same source for the whole migration
(see § Composing sources across surfaces).

### 1. Existing tests

The cheapest judge, and the only one that is free. It qualifies when two things hold: the tests
cover the migration surface (measured — see below, not assumed), and they assert on observable
behavior rather than on the outgoing technology's API shape. A suite that fails the second condition
is not a judge; it is a second migration target, and the coupling inventory says how big.

### 2. Authored baseline: golden master

When existing tests do not reach the level, capture the current behavior of the old code as data and
diff the new behavior against it. Golden master is the workhorse form: record real inputs and the
outputs the current implementation produces — serialized bytes, rendered trees, response payloads,
log traces — and make the migrated code reproduce them exactly. It is strong where it applies,
because it asserts on the whole observable output instead of the fields someone remembered to check,
and it needs no understanding of *why* the output is what it is.

Two things it does not give you. It cannot tell a preserved behavior from a preserved bug — that is
the point, and it is why a golden-master diff that "looks wrong" is a question for the product
owner, not a licence to edit the baseline. And it is only as good as the input corpus: a recorded
corpus that never exercises the error path leaves the error path unjudged, which is a coverage
question, not a golden-master question.

Writing test code for this baseline is out of scope for this skill — it is handed to
`test-authoring-role` (see `[[safety-net]]` for the handoff and its schema). Writing tests that pin
current behavior instead of asserting correctness is a mode of test authoring — commonly called
characterization — whose semantics and disciplines are owned by the skill that fills that role
(e.g. `write-tests`), and are deliberately not restated here.

### 3. Runtime scenario parity

When behavior is not capturable as data — it lives in a running system, an interaction sequence, a
rendered screen — the judge becomes execution: drive the same scenario against the pre-migration
build and the post-migration build and compare what is observed. This is what `scenario-judge-role`
executes. It is the most expensive source and the only one available for cross-cutting migrations
where the failure mode is a wiring graph that no unit test instantiates (see `[[cross-cutting]]`).

Scenario parity is only a judge if the scenarios are written down before the run. An operator
clicking around after the fact produces an impression, not a verdict. The deliverable is an ordered
list of scenarios with the observation each one makes, stable enough to re-run on both builds.

Post-release monitoring is not a fourth source. It observes a migration that already shipped, which
makes it compensation for coverage the judge lacked, not judgement — it belongs to `[[safety-net]]`.

### Composing sources across surfaces

"Stop at the first source that reaches the required level" is a rule about one surface, not about the
migration. The ordinary case on a real migration is a **split judge**: source 1 reaches the level on
one surface and stops short on another, so source 2 or 3 is built for the remainder only. A
serializer swap where the existing suite pins the encoded bytes but nothing exercises decoding is the
recurring shape — the composite judge is "existing tests on the encode side, golden master on the
decode side", and that is a normal outcome, not a sign the analysis went wrong.

Two conditions keep a composed judge honest:

- **The split is written down by surface, not by source.** Name each surface of the migration and,
  next to it, the source that judges it and the level that source reaches there. A source listed
  without the surface it covers is a claim that it covers everything.
- **The composite reaches the minimum valid level only if every surface does.** The weakest surface
  sets the verdict. A surface left with no source is not a cheaper composition; it is an unwatched
  row, and it goes to the safety-net decision (Phase 0 output 9) like any other.

## Building the differential corpus

Mandatory wherever the judge compares recorded output: a golden master, a byte-for-byte payload
comparison, or an existing test that pins an emitted value. Such a judge is not built until its
**input corpus** is built. A single recorded sample is an illustration, not a golden master — it
fixes one point of the input space and reads as though it pinned the format. The step is bound to
the judge's *form*, not to its source: a suite that already pins one payload string (source 1)
needs the corpus exactly as much as a baseline authored from scratch (source 2).

The form is a **differential probe**: run the old implementation and the new one side by side over
the same list of inputs and diff the two outputs, instead of asserting the new output against one
remembered string. Diffing two runs is what makes an unexpected divergence visible; a single
assertion can only report the case someone already suspected.

What is owned here is the corpus *specification* — the input classes below and the ordering
constraint — as a step of judge construction. Writing the probe code itself is test authoring like
any other and goes to `test-authoring-role` under the handoff above.

**Record while the old implementation is still on the build.** The probe runs against the old code
first, and its output is a Phase 0 artifact. Once the dependency is swapped, "before" cannot be
reproduced, and the corpus degrades into whatever the new code happens to emit.

### The input classes

Cover every class below, or state per class why it cannot apply to this surface. The input-class
checklist exists so that corpus breadth does not depend on the executor's inventiveness — how many inputs a
class needs is judgement, whether the class is present is not.

- **Escaping and special characters.** Quotes, backslashes, control characters, and the punctuation
  engines disagree about. The recurring find: one engine escapes `& < > ' =` as `\uXXXX` and the
  other has no such option at all, so the bytes diverge on input as ordinary as `Ben & Jerry`.
- **Non-ASCII.** Accented text, non-Latin scripts, emoji and surrogate pairs — escaped or emitted
  literally is an engine-level choice.
- **Numeric boundaries.** Minimum and maximum of each width, zero, negative, and values that force a
  representation change (a fractional value where an integer is declared).
- **Fields left at their default and fields set explicitly.** Both, as separate inputs. Whether a
  defaulted field appears on the wire at all is exactly what a round-trip test cannot see.
- **Missing keys and unknown keys.** Absent required fields, absent optional fields, extra keys, and
  keys renamed by the mapping under migration.
- **Empty and null values.** Empty strings, empty collections, explicit nulls, and an empty
  container.
- **Malformed input.** Syntactically invalid payloads, truncated payloads, trailing content, and
  wrong top-level shape. Whether it throws, what it throws, and what it silently accepts are all
  observable.

### Compatibility settings must be shown to be load-bearing

A migration that restores old behavior through configuration — a flag that keeps defaults on the
wire, a flag that tolerates unknown keys — has added a judge dependency that can regress silently,
because removing the flag still compiles and still passes every test that was never written for it.
Verify each such setting by **removing it alone and confirming the probe goes red**, one setting at
a time, and record which case each one defends. A setting whose removal changes nothing is either
decorative or unwatched, and both readings are findings.

Divergences the corpus turns up are input to the parity decision, not automatically defects to
close: some of them are the old implementation's bugs, and preserving those is a product question
under the rule above, not a licence to edit the baseline.

## Judge coverage assessment

Phase 0 output 4. The question is narrow and inward-facing: **of the code this migration touches,
how much does the judge actually observe?** It is not a work order and not a request for anyone to
write tests — that artifact is the coverage-gap handoff report in `[[safety-net]]`, a different
thing with a different audience. Do not use the two terms interchangeably.

The assessment takes one of two forms, and which one applies is decided by the surface before
anything is measured, not by the number after it is seen. **Instrumented measurement** applies when
the migration's failure modes are things a line or a branch either executes or does not: call sites,
error paths, conditional handling. A **behavioral checklist** applies when they are not — the cases
listed under § Behavioral checklist where line coverage is meaningless. Two consequences that get
mishandled in opposite directions: having no coverage tool in the stack is not a licence to estimate
a percentage — either wire one up, or establish that the checklist form applies and the percentage
was never the deliverable; and a tool that *is* installed but produces a number meaningless for this
migration gets quoted as context at most, with the checklist as the actual output. The installed tool
does not decide the form; the surface does.

Where the assessment is instrumented, three properties make the number mean something.

**Measured with the stack's own tool.** Line and branch coverage from whatever the stack already
runs — a coverage report, not an estimate from reading the test directory. An unmeasured "the tests
look decent" is the single most common way a migration acquires an imaginary judge.

**Scoped to the migration.** Repo-wide coverage is noise here. The denominator is the set of files
and symbols the migration will touch, as identified by the Phase 0 read of the target code that
produced outputs 1-3. It is deliberately not the work queue from `[[depmap-and-queue]]` or the gap
inventory: both are Phase 1 artifacts and do not exist yet, so an output that waited for them could
never be produced. Phase 1 refines the set; a refinement that moves it materially is a reason to
re-run this assessment, not a reason to have deferred it. A repo at 70% can be at 15% on exactly the
package being swapped, and the repo number hides it.

**Measured on the old code, before the migration starts.** The number must describe what the judge
watched *before* anything moved. Run after the fact and it measures the migrated code plus whatever
tests were adjusted to keep it green — which is the thing under suspicion, used as evidence for
itself. Capture the report as a Phase 0 artifact.

### Executed is not asserted

Coverage tools report execution, not judgement. A line that runs inside a test whose assertions
never touch its effect is covered and unjudged. So the number is an upper bound on what the judge
sees, never a floor: 80% line coverage means at most 80% is watched. Where the gap between executed
and asserted looks large — smoke-style tests that construct a lot and assert little — say so in the
assessment rather than quoting the percentage bare.

### Behavioral checklist where line coverage is meaningless

Some migration surfaces produce a coverage number that is true and useless. Substitute an explicit
checklist of observable behaviors and mark each as watched or unwatched, by name:

- **Wiring and injection graphs.** Registering a binding executes the registration line; nothing
  asserts that resolution returns the right instance with the right lifetime. Coverage happily
  reports 100% on a graph that is wrong.
- **Declarative UI.** Executing a composable or view builder is not observing what it renders.
- **Byte-level serialization.** Encoder code runs on every test that round-trips a value; field
  order, discriminator encoding and numeric width are unasserted unless something inspects the
  bytes. Byte-for-byte compatibility is a separate acceptance criterion (`[[scope]]`
  § Serialization).
- **Generated code.** Coverage of generated sources measures the generator's output volume, not the
  contract you care about; judge the contract at its call sites instead.
- **Concurrency and dispatch.** A coroutine or queue swap executes the same lines; ordering,
  threading and cancellation are what changed, and lines do not record them.

The checklist output is a list, one row per behavior, each either "watched by X" or "unwatched".
Unwatched rows are the input to the safety-net decision (Phase 0 output 9). On these surfaces the
checklist **replaces** the percentage as this output rather than accompanying it as a softer version
of the same claim — reporting both invites the number to be read as the verdict it cannot support.

## Test coupling inventory

Phase 0 output 5. Classify the tests that cover the migration surface by what they are welded to.
This is what tells you whether the suite survives the migration or is part of its cost.

**Agnostic** — the test asserts on observable behavior and would compile and pass against either
implementation: given this input, the parsed object has these values; given this action, the screen
shows this text. Agnostic tests migrate for free and are the judge you want.

**Coupled** — the test names the outgoing technology in its setup, its assertions, or its expected
values: it builds the old library's types, mocks the old interface, reaches into internals only the
old implementation has, or pins an output that is an artifact of the old implementation and that the
new one is under no obligation to reproduce. A coupled test does not survive the migration untouched,
and — the part that gets missed — **it cannot judge the migration either**, because making it compile
against the new code means editing the assertions whose stability was the whole point.

**Contract-bound** — an agnostic test whose expected value *is* the contract the migration must
preserve: the exact wire bytes, the shape of a payload, an on-disk record, an observable protocol
exchange, the rendered text of a screen. The old implementation merely happened to produce that value
first; the value is not its property. This is the case the two labels above are most often misapplied
to, because such a test does pin a literal that the outgoing library emitted — and it is nevertheless
the strongest judge in the tree, the built-in golden master a serialization or protocol migration
would otherwise have to author from scratch.

**The discriminator: ask what the expected value does if the migration is correct.** Bound to a
preserved contract → it stays byte-identical, and any change in it is a defect by definition; the
test is the judge. Coupled to the outgoing technology → it legitimately changes, because what it
pinned was a detail of the library being removed. That question is the only decider. "It still
compiles against the new code" is a screen, not an answer: it rules out coupling by type — imports,
mocks, internals — and says nothing about a pinned value, because a test that pins an artifact of the
old implementation compiles perfectly well and merely fails. Passing the screen buys the right to ask
the question, not a verdict. Two migrations can pin the same literal and land on opposite sides — the
classification is a property of the contract, not of the string.

The inventory is one row per test file or class: name, agnostic (marking the contract-bound ones,
because they are judge candidates before any other source is considered) or coupled, and for coupled
rows what it is coupled to. Count the coupled rows before choosing a judge; a surface that is 100%
covered by coupled tests has, for migration purposes, no judge at all.

Every coupled row gets exactly one of three remedies, decided in Phase 0, not during the loop:

1. **Rewrite at an agnostic level.** Re-express the same intent one level further out — assert on
   the value the parser returns rather than on the parser's internal calls, on rendered text rather
   than on the view type. Correct when the behavior under test is real and only the expression of it
   was bound to the old technology. Cost: authoring work, handed to `test-authoring-role`. This is
   the default when the test guards behavior that must keep working after the migration.
2. **Replace with a golden master.** Drop the assertion set and capture the current output as a
   baseline instead (source 2 above). Correct when the behavior is wide, mechanical, or tedious to
   re-express by hand — serializer output, large response mapping, rendered trees — and when the old
   code can still be run to record it. Cheaper than rewriting and usually stronger, since it
   captures fields nobody thought to assert on.
3. **Accept as single-use and retire it.** The test exists only to pin an idiom of the outgoing
   technology and has no meaning once that technology is gone. Correct when the assertion would have
   no reader after the migration. Mark it in the inventory as scheduled for deletion so it is not
   mistaken for coverage while the judge is being chosen, and delete it in the migration's own
   commit rather than leaving a permanently skipped test behind.

The decision rule between them: rewrite when the behavior matters and is narrow, capture when the
behavior matters and is wide, retire when only the old idiom mattered. The fate of baseline tests
authored during the migration is a different question, decided after it — see `[[safety-net]]`.

## Legacy profile: no tests

A codebase with no usable test suite is a **first-class migration profile with its own judge**, not
an emergency and not a reason to refuse the work. INV-3 is explicit about this: structured manual
scenario parity plus a golden master is a valid judge. Migrations of exactly this kind — old code,
no coverage, the technology underneath end-of-life — are among the most valuable ones there are, and
a skill that only works on well-tested code would decline most of the work that needs doing.

What the profile looks like when Phase 0 detects it (output 7): no automated coverage of the
migration surface, or a suite that exists but never runs, or a suite that runs but whose coverage of
that surface is entirely coupled to the outgoing technology (output 5, § Test coupling inventory
above), or no regression pass before release. The third form is the one that hides: the tests are
green today and gone tomorrow, so the profile is about having no judge, not about having no test
files.

The judge for this profile has two halves, and both are required:

**Structured manual scenario parity.** Written before the migration, from the old code and from
whoever knows the product: an ordered list of scenarios covering the surface being migrated, each
with its inputs and the observation that decides pass or fail. Written down is the load-bearing word
— the artifact must be re-runnable by a different person on the post-migration build and produce the
same verdict. Run it once against the old build first: that pass is the baseline, and it is also how
you find out that a scenario was ambiguous while it is still cheap to fix. Execution belongs to
`scenario-judge-role`.

**Golden master over whatever the old code can be made to emit.** Anything the legacy system already
produces as data is capturable without writing tests around its internals: serialized files,
database rows, request payloads, log output, rendered output. Prefer capturing at the outermost
boundary you can reach — it is the boundary least likely to move during the migration. This half is
often the stronger of the two, because it needs no product knowledge at all.

### Semi-automating the manual half

Manual scenario parity does not have to stay manual. Where the platform exposes a structural
description of what is on screen — an accessibility or UI tree, a serializable view hierarchy —
capture that tree at each scenario step on the old build and diff it against the new one. This turns
a human judgement ("the screen looks the same") into a mechanical comparison with a recorded
artifact, and it converts the scenario list into a golden master. Bind that capability to
`scenario-judge-role`; it is the same role, better equipped, not a new one.

The parts that resist capture — animation, timing, feel — stay human and stay on the list. Marking
them explicitly is what keeps the semi-automated run honest about what it did not check.

### The residual risk, stated

This judge is weaker than a good test suite and the plan should say so out loud rather than imply
parity. It watches the scenarios someone thought of, at the boundaries someone could capture. Rank
the migration surface against the scenario list and name the parts no scenario reaches; those
unwatched parts are the input to the safety-net decision and, if they carry real risk, the reason to
stop and build coverage first (`[[safety-net]]` § Three entry branches).
