# Dependency map and work queue

Both mechanisms in this file are **patterns, not tooling**. Nothing here ships as a script; the
agent running a migration generates a dependency map and a work queue in place, in whatever form
fits the stack — a text list, a small table, a scratch file next to the RULEBOOK. What is fixed is
the shape of the pattern and the guarantee it buys, not an implementation.

## Dependency map (generate in place)

The dependency map orders translation so that a file is only translated after everything it needs
to compile against has already been translated (or is stable enough not to matter). It is built
once in Phase 1, from the same pass over the codebase that seeds the RULEBOOK, and it does not need
to be exact — it needs to be a deterministic, reproducible ordering that two runs of the same
analysis would agree on.

Building it:

1. Enumerate the files or units in scope for the migration.
2. For each one, list what it depends on that is also in scope (imports, references, injected
   collaborators — whatever the stack's dependency relation is).
3. Produce a topological order over that graph: a file appears after everything it depends on.

**Cycles are handled as one batch, not resolved by breaking the cycle.** A cycle in the dependency
graph means the files inside it cannot be individually ordered relative to each other without
inventing an artificial cut that the source code does not actually have. Rather than force an
order, treat every file in a cycle as a single unit of work: translate all of them together, verify
them together, and let the queue mark the whole cycle done at once. Breaking a cycle by picking an
arbitrary member to go first is a decision the RULEBOOK should own explicitly if it is ever needed
— it is not the dependency map's job to make that call silently.

**For cross-cutting topology, the dependency map is a graph of injections, not of files.** When the
unit of work is an aspect of the graph (a DI container, a logging backend) rather than a single
file, the map orders the aspect's touch points — where the aspect is configured, where it is
injected, where call sites consume it — the same way it would order files in a localized migration.
The topology distinction and its consequences (interop bridge vs big-bang, why the compiler is not
a referee here) belong to `cross-cutting.md`; this file only supplies the ordering mechanism that
cross-cutting migrations reuse.

## Work queue (generate in place)

The work queue tracks what remains to be translated. Its state lives entirely on disk, in the
target files the migration produces — there is no separate queue file, database, or in-memory list
that must be kept in sync with reality.

The rule that makes this work: `done = target file exists on disk`. A site is done when its
migrated output exists where the RULEBOOK says it should; it is not done otherwise. There is no
third state and no separate bookkeeping to fall out of sync with the code.

**The queue is rebuilt from disk at the start of every cycle, not carried forward from memory.**
Each cycle, re-derive "what remains" by diffing the dependency map's full site list against what
already exists on disk, honoring the topological order from the dependency map. This is why the
mechanism is **resumable by construction**: nothing about progress is stored anywhere that an
agent's death, a context compaction, or a session restart could lose. The queue is not resumed —
it is recomputed, and recomputing it always produces the same answer a from-scratch run would,
because the only source of truth is the disk state the previous cycle actually left behind. An
external state file would need to be kept consistent with the filesystem by hand; deriving the
queue from the filesystem removes the category of bug where the two disagree.

This also means a batch never has to be told to "continue from where it left off" — every cycle
already starts by asking the disk what remains, so the next cycle behaves identically whether the
previous one finished, crashed, or was interrupted mid-batch. The `TODO(port)` / `BUG(port)` /
`PERF(port)` markers from `rulebook.md` layer on top of this same idea: a marker in an existing
target file means the site exists but is not actually done, so the work queue's plain
existence check is not the *only* gate before Phase 6 — a done site with an open marker is still an
open item for the gap inventory, even though the file is on disk.

## Waiting on the queue

A cycle that dispatches translation, compilation, or review work must wait for that work to finish
before rebuilding the queue for the next cycle — and that wait is a **poll on a real condition
with a hard upper bound**, never a fixed sleep chosen to be "probably long enough." Poll for the
actual signal the cycle depends on (a file appearing, a process exiting, a log line showing up),
on a short interval, and stop polling and fail loudly once the upper bound is reached rather than
continuing to wait silently. A fixed sleep either wastes time when the condition resolves early or
produces a flaky failure when it does not resolve in time — an upper-bounded poll does neither, and
a loud failure at the bound gives the operator something to act on instead of a migration that
silently never progressed past a cycle. The environment this skill runs in may already provide a
small helper for this poll-with-timeout shape (e.g. `wait-for.sh`); use it if present, otherwise
implement the same poll-with-bound shape directly.
