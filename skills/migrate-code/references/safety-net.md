# Safety Net

This file owns the entry into a migration through coverage: what to do when Phase 0 finds no
reachable judge with the tests that exist today. It owns three entry branches, the deliverable
boundary, the coverage-gap handoff report schema, the post-migration fate of characterization tests,
and the compensation available when nothing better is reachable.

Adjacent ownership, do not re-derive here: verification levels L0-L5 are defined in
`[[verification-matrix]]`; the judge coverage assessment and the test coupling inventory are
produced in `[[judge]]`; the IN/OUT taxonomy and the two STOP conditions belong to `[[scope]]`.
The disciplines of writing characterization tests — how to pin behavior, how to name what was
captured — belong to the test-authoring skill of the environment, not to this file.

## Three entry branches

Phase 0 output 9 is a safety-net decision, and the decision has exactly three answers. Pick by the
two Phase 0 measurements that already exist: the risk rank of the surface being migrated, and how
much of that surface the current judge actually watches.

1. **Safety-net-first — stop the migration and grow coverage before any code moves.**
   Choose when the migrated surface carries P0/P1 risk *and* the judge sees materially none of it,
   or when the migration is cross-cutting (a graph or a shared layer) so the failure mode compiles
   cleanly and only a runtime observer can catch it. The cost is a full pause; the payoff is that
   Phase 6 has something to discharge its claim against. This branch is the only one that turns a
   NO-GO under `[[scope]]` § STOP conditions into a GO.

2. **Golden-master baseline — capture what the system does today, without claiming it is right.**
   Choose when behavior is observable end to end but not specified: legacy code whose intent is
   lost, screens with no assertions, pipelines whose output is a file or a payload you can snapshot.
   The baseline is a recording, not a specification. It has no authority over whether the current
   behavior is correct — it only fails when the migration changes it. State that explicitly when
   reporting, because a golden master that is silently read as "the tests say it is correct" invites
   a wrong bug fix to be reverted as a regression later.

3. **Incremental coverage-as-you-go — grow coverage batch by batch, ahead of each batch.**
   Choose when the migration is localized (each site independent), risk is P2/P3, and the work queue
   is long enough that a full up-front pause would dominate the schedule. The rule that keeps it
   honest: coverage for a batch lands **before** that batch is translated, never after. Coverage
   written after the translation encodes the new behavior and proves nothing about parity.

Two branches can combine — a golden-master baseline over the observable surface plus incremental
unit coverage per batch is common. What is not allowed is choosing none of them and proceeding: the
absence of a judge is not resolved by starting work and hoping one appears.

## The seam trap

Getting code under test often requires a seam — an injection point, an extracted interface, a
constructor parameter where a static call used to be. Creating that seam is a refactoring, and a
refactoring of the code you are about to migrate is itself a **mini-migration**: same technology
underneath, same absence of a judge, same need to prove behavior survived. That is the trap, and it
recurses if you let it — building a seam requires a test, the test requires another seam, and the
preparation consumes the task it was supposed to enable.

Three rules keep it bounded:

- **Do not recurse.** A seam refactoring gets no safety net of its own. It is justified only when
  the change is compiler-checked or mechanical enough that the compiler is a valid referee at L0-L1
  — extract an interface, add a parameter, move an instantiation up one level. If a seam needs a
  behavior judge to be safe, it is not a seam, it is a second migration, and it goes back to Phase 0
  as its own job.
- **Budget it before starting.** Name a bounded share of the migration effort for seam work at
  Phase 0 and treat overrun as a signal, not as an overspend to absorb. When the budget is exhausted
  and the seam is not in place, the honest outcomes are a coarser judge one level up (test the
  system where it is already observable rather than where you wish it were) or a NO-GO — not a
  deeper refactoring.
- **Prefer observation over surgery.** A judge attached to an existing observable boundary — a
  process boundary, a screen, an emitted artifact — costs nothing in seams. Reach for the surgical
  seam only after the outer boundary has been ruled out as too coarse to distinguish the failure
  mode you actually fear.

## Embed or extract

The coverage work is either a phase inside the migration or a separate deliverable that precedes it.
This is a real fork with different reporting, different review, and different ownership — decide it
in Phase 0 and say which one you chose.

**Embed** — the coverage step runs between Phase 0 and Phase 1 of the same job. Choose when the
volume is small (hours, not days), the tests are scaffolding whose whole purpose is to survive until
Phase 6, and the migration fits in one working session so the context that produced the coverage is
still the context that consumes it.

**Extract** — coverage is delivered and accepted on its own before the migration is scheduled.
Choose when any of the following holds:

- **Volume.** The coverage work is comparable to or larger than the migration itself.
- **Durability.** The tests are a permanent asset — they describe behavior the project wants pinned
  regardless of this migration, so they should be reviewed on their own merits and not as migration
  scaffolding.
- **Session boundary.** The work will not fit in one session, or the authoring is done by a
  different executor (frequently a human, see `## Coverage authoring: automated vs manual`). Then the
  coverage-gap handoff report is not a convenience — it is the only carrier of intent across the
  boundary.

The default when the criteria are mixed is extract, because the failure mode of embedding is worse:
an embedded coverage phase that overruns silently converts the migration into a testing project with
no acceptance of its own, while an extracted one that overruns is visible as a late deliverable.

## Coverage-gap handoff report

A coverage gap identified in Phase 0 is handed to `test-authoring-role` as a report with a fixed
six-field schema. One report per gap. The recipient is a **role**, not a named tool: whichever
agent, skill, or person fills the role in this environment consumes the same schema.

| Field | Meaning |
|---|---|
| `target` | The site, symbol, or screen to be covered |
| `baseline` | Reference to the current implementation plus the observable effects to pin |
| `risk_rank` | P0-P3, taken from the verification matrix and blast radius |
| `coupling` | `agnostic` or `coupled` — whether the test is welded to the outgoing technology |
| `judge_level` | Minimum valid level L0-L5 that the resulting test must reach |
| `test_type` | Proposed type: unit, screenshot, graph-verify, or scenario |

Worked example:

```
target:      CartTotalsCalculator.applyPromotions
baseline:    current implementation at the call site listed in the gap inventory;
             observable effects to pin: returned total, order of applied promotions,
             the rounding of the discount on a 3-item cart with two stacked promotions
risk_rank:   P1
coupling:    agnostic
judge_level: L2
test_type:   unit
```

**Why `baseline` is in the schema.** The other five fields describe a work order; none of them says
what the correct answer is. An automated executor on a stack it knows can often read the current
implementation itself; a manual executor receives a target with no specification of what to capture
and either guesses or asks. The `baseline` field carries the reference to the current implementation
and the observable effects that must be pinned, which is exactly the information a characterization
test needs and no other field supplies.

**The report is optional for the receiving side.** The consumer must be able to work without it —
"characterize this class" with no report is a valid request and must remain one. The report is an
accelerator that removes a discovery step, not a protocol dependency, and no receiver may make the
report a precondition for doing the work.

Two notes on filling it in. `risk_rank` and `judge_level` are copied from Phase 0 artifacts, not
re-estimated here — a report that disagrees with the verification matrix means the matrix is stale
and gets fixed there. `coupling` is copied from the test coupling inventory in `[[judge]]` and is the
field that decides what happens after the migration, below.

## Fate of characterization tests

Characterization tests written to enable a migration are not automatically part of the project's
permanent test suite. When Phase 6 has passed, every such test gets one of two dispositions, decided
per test and reported explicitly. Silence is not a disposition: an unreviewed characterization suite
becomes maintenance debt that nobody remembers agreeing to.

**Criterion:** a test that pins an idiom of the outgoing technology is a delete candidate; a test
that is agnostic to the technology stays. This is the `coupling` field of the handoff report, read
after the fact.

- **Keep — the test is an asset.** It asserts on behavior stated in the domain's own terms: inputs
  and outputs, screen contents, emitted payloads, error semantics. It would have been worth writing
  even without the migration, and it will keep failing usefully after the outgoing technology is
  gone. Fold it into the regular suite, under the regular naming and review conventions.
- **Delete — the test is debt.** It asserts on the mechanics of the technology being removed: mocks
  of the old library's types, snapshots of a rendering model that no longer exists, assertions on a
  callback ordering that the new mechanism does not have. Post-migration it either fails to compile,
  needs continuous rewriting to keep passing, or passes vacuously. Removing it is the completion of
  the migration, not a loss of coverage — the coverage it nominally provided was coverage of code
  that no longer exists.

The ambiguous case — an agnostic assertion reached through a coupled fixture — is a rewrite, not a
third outcome: keep the assertion, replace the fixture, and if that rewrite is not worth its cost the
disposition is delete.

## Post-release compensation

Some projects run real production traffic while releases are checked by limited manual testing and
no regression pass exists before release. For that profile, when no branch above yields a judge
strong enough for the risk, the remaining lever is to move detection after the release:

- **Staged rollout.** Ship the migrated code to a small share of traffic first and widen only on a
  clean signal. The exposure of a defect is then bounded by the share, and rollback is a
  configuration change rather than a new release.
- **Crash-free and error-rate monitoring.** Watch crash-free sessions, error rates, and the handful
  of business metrics the migrated surface touches, with a pre-agreed threshold and a pre-agreed
  rollback owner. Thresholds and owner are agreed **before** the rollout starts; agreeing on them
  while a metric is dropping produces negotiation, not a rollback.

**This is a weaker level than coverage, and it must be reported as weaker.** It detects, it does not
prevent: users see the defect first, and only failures that surface as a crash or a moving metric are
visible at all — silent wrong results, corrupted persisted data, and byte-format drift pass every
monitor listed above. It is a legitimate compensating control on a P2/P3 surface and a legitimate
supplement on any surface. It is never a substitute for a judge on a P0/P1 surface, and stating
"we have staged rollout" does not close a coverage gap in a Phase 6 report.

## Coverage authoring: automated vs manual

The three entry branches are not equally executable everywhere, and the difference is a property of
the stack, not of the migration. `[[scope]]` states the ownership side of this boundary — assessing
coverage is in scope, authoring test bodies is not. Here it decides how the chosen branch actually
runs:

- **Automated.** Where the environment provides a tool that fills `test-authoring-role` — Kotlin and
  Swift stacks are the ones with one available today (e.g. a characterization-mode test-writing
  skill) — the handoff is a delegation. Coverage authoring runs unattended, safety-net-first and
  coverage-as-you-go stay cheap, and the batch-by-batch cadence of branch 3 is practical.
- **Manual.** On every other stack the role is filled by a person. This is a degraded but supported
  mode, not an unsupported one. Plan for it: the pause of branch 1 becomes a scheduling dependency
  rather than a step, extract usually beats embed (see `## Embed or extract`), and branch 2's
  golden-master baseline is often the cheapest reachable option because a recording needs less
  authoring than a specification.

Do not hide this boundary from the user when proposing a mode in Phase 0. A plan that assumes
unattended coverage authoring on a stack that has none is a plan whose safety net silently never
gets built.
