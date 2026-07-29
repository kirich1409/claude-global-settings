# RULEBOOK, markers, gap inventory

The RULEBOOK is the single source of translation decisions for a migration. Every worker
translating a file reads the same RULEBOOK and applies it without judgment calls; nothing is
decided per-file that could instead be decided once, in the rule.

## Building the RULEBOOK

Start it in Phase 1, before fan-out. Seed it from the Phase 0 taxonomy and from a first pass over
a handful of representative files — enough to name the recurring shapes, not an exhaustive catalog
up front. Each entry states a source pattern, the target pattern it becomes, the rationale in one
line, and any named exceptions. An entry with no rationale is a preference, not a rule, and will not
survive the first disagreement in review.

Phase 2 exists to break the RULEBOOK on purpose: run it against a few hand-picked awkward files
before trusting it against the whole tree. A rule that has only ever seen the easy case is a guess
wearing the shape of a rule.

Use `rulebook-template.md` as the skeleton to copy verbatim when starting a new migration.

## Fix the loop, not the code

A systematic defect found during translation or review is a defect in a rule, not in the one file
where it surfaced. The fix is: amend the rule, then re-run every site the rule touched — never
patch the individual file in place and move on. A patch that bypasses the rule is invisible to
every other site the same defect exists in, and the next pass will silently reintroduce the defect
wherever the file gets touched again.

This is the same discipline as fixing a bug at its root cause instead of at its first symptom,
applied to translation instead of to logic: the rule is the artifact that gets corrected, the
translated files are its output and get regenerated from it.

## Read-only in the loop

The RULEBOOK is **read-only inside the loop**, read-only inside a batch in particular. A worker
translating file N does not amend the rule
that governs file N — even when the rule looks wrong from where they are standing. Amendments are
proposed, reviewed, and applied **only between batches**, after the current batch has finished and
before the next one starts. Reasoning: a rule changing mid-batch means files 1 through k in the
same batch were translated against a rule that no longer exists, and nobody can tell which files
those were without re-diffing the whole batch.

Findings that would change a rule route back to the RULEBOOK for the next batch boundary, not
sideways into the file that exposed them.

## Markers

Three markers record work a rule cannot yet resolve mechanically. Each one is planted at the exact
site it applies to, and each one earns a row in the gap inventory.

- `TODO(port)` — the site has no rule yet; a human or a stronger role needs to decide the mapping
  before this site can be resolved.
- `BUG(port)` — the mechanical translation is known to be behavior-changing at this site and the
  fix is not a mechanical rule; it needs targeted correction.
- `PERF(port)` — the translation is behavior-preserving but changes performance characteristics
  enough that it needs a deliberate decision, not a default.

A marker without a matching gap inventory row is a leak: the site is flagged in the code but
invisible to whoever is tracking what remains. A batch is not done while any marker it introduced
lacks a row.

## Gap inventory

One row per site that cannot be translated mechanically by the RULEBOOK. The inventory is the
single place that answers "what is left" without grepping the whole tree for markers — it is
appended to as sites surface during translation and review, and a row is only removed once its
marker is resolved and the corresponding code no longer carries it.

Use `inventory-template.md` as the skeleton to copy verbatim.
