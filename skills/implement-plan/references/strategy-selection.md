# Strategy selection: DAG layering, parallelism & worktree isolation

How Phase 1 turns `tasks.md` into an execution strategy. The guiding bias: **sequential is the
default; parallelism is an optimization that must prove it is safe.** Correctness never depends on
parallel execution — it only ever makes a safe run faster.

## 1. Build the layers

Each task in `tasks.md` carries `after: <T-… | none>`. Treat these as edges and compute topological
**layers**:

- **Layer 0** — every task with `after: none`.
- **Layer N** — every task all of whose dependencies are in layers `< N`.

A layer is a set of tasks that are *dependency-free relative to each other*. That makes each layer the
only place parallelism is even a candidate — tasks across layers have an ordering that must be honored.

A cycle (`after:` chain that loops) is a malformed plan: stop and report it; do not guess an order.

## 2. Decide sequential vs. parallel — per layer

For each layer with ≥2 tasks, parallelize **only if all** of these hold:

- **Disjoint files.** No two tasks in the layer list overlapping `files:`. Overlap → two writers on one
  file → sequential.
- **No shared mutable state.** Tasks don't both touch the same migration, generated file, global
  config, or lockfile even if the listed `files:` differ. When the plan is ambiguous about this,
  assume shared → sequential.
- **No shared risk tag.** Neither task is flagged risky/architectural in the plan (those get a human
  pause under `--interactive`, not a concurrent race).

If any condition fails, run the layer sequentially. A single layer may be *partly* parallel: split it
into a parallel group of provably-disjoint tasks plus a sequential remainder.

`--sequential` skips this analysis entirely (everything in order). `--parallel` forces fan-out wherever
the three conditions hold, but **cannot** override them — a collision is always resolved sequentially.

## 3. Worktree isolation for parallel tasks

Concurrent subagents editing the same working tree corrupt each other. So each parallel task runs in
its **own git worktree** under `.worktrees/` (gitignored, per [[git-workflow]]), branched from the
current working branch:

1. Create `.worktrees/<slug>-<T-N>` off the working branch for each parallel sibling.
2. Dispatch one implementer subagent per worktree; each implements + runs its `check` in isolation.
3. **Integrate one at a time.** As each sibling's `check` passes, merge/rebase its worktree back into
   the working branch, then remove the worktree (`worktree-cleanup`). Serializing integration keeps the
   branch history linear and surfaces conflicts one at a time.
4. **On an integration conflict:** stop parallel integration for that layer, keep the already-integrated
   results, and re-run the remaining siblings sequentially on the now-updated branch. A conflict means
   the disjointness assumption was wrong — demote, don't force.

For a purely sequential run, no worktree is needed: the implementer works the current tree directly
(still a subagent — the main session never edits code).

## 4. Resume semantics

`--resume` reads `progress.md` as the source of truth (never the chat or the ephemeral TodoWrite list,
which does not survive a session — [[context-resilience]]):

- Every `[x]` task is treated as `completed`; its TodoWrite item is seeded `completed`.
- Execution restarts at the first `[ ]` task, recomputing layers over the *remaining* tasks so an
  interrupted parallel layer resumes correctly.
- A task left `in_progress` in a prior run but unchecked in `progress.md` is **not** trusted as done —
  it re-runs from scratch. Half-finished work is re-verified, never assumed.

## 5. `--dry-run` output

Print, and dispatch nothing:

- The resolved layers (`Layer 0: T-1 · Layer 1: T-2, T-3 · …`).
- Per layer: sequential or parallel, and *why* (e.g. `parallel — disjoint files`, `sequential —
  T-4/T-5 share src/db/schema.sql`).
- Per task: the `model × effort` the dispatch would use and the `check` that will gate it.

This is the "think through the options at launch" preview — it lets a human sanity-check the strategy
before any code is written.
