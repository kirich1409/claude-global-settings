Referenced from: `~/.claude/skills/finalize/SKILL.md` (§Phase 0 — Deep scan, §Phase A — Semantic review).

# Finalize — Phase 0 Detail and Phase A Rationale

Effort-selection mechanics, binding-check fallback, and ingestion/discard rules for the
Phase 0 deep scan, plus the rationale for keeping a dedicated `code-reviewer` in Phase A
alongside Phase 0's `/code-review`. SKILL.md keeps the control flow (when each phase runs,
what to do with its findings); this file holds the supporting detail.

## Phase 0 — Deep scan detail

### Effort selection (`auto`)

Scale recall to blast radius using signals finalize already materializes pre-loop — the diff (`swarm-report/<slug>-diff.txt`), the context artifact's `risk_areas`, and a cheap pass of the [Security-expert pattern triggers](reviewer-matrix.md#security-expert-pattern-triggers) table over the diff. No new computation, no extra agents. An explicit `--deep-scan-effort` always wins over `auto`. Evaluate top-down, **first match wins**; the floor is `medium` (anything below it is a trivial diff, already skipped above):

| Tier | Fires when (any) |
|---|---|
| **max** | ≥ 1 *narrow* security pattern in the diff, OR declared `risk_areas` ∈ {auth, payment, pii, data-migration}, OR a DB-migration path — same bar that triggers a full Phase D security review; a missed bug here is the most expensive. |
| **xhigh** | tech / infra-layer change (network, storage, auth, DI per `~/.claude/rules/task-types.md`), OR new public API spanning ≥ 2 modules, OR diff > 500 LOC or > 15 files. High blast radius. |
| **high** | new public API symbol, OR cross-module dependency change, OR diff > 150 LOC or > 6 files. Default for substantive features. |
| **medium** | everything else above the trivial-skip bar — localized change, no risk signal. |

Record the resolved tier and the signal that picked it in the report (`Phase 0 (deep scan): effort=xhigh — reason: infra-layer (network)`), so a surprising cost is traceable to a concrete trigger and the thresholds can be tuned against real runs.

### Binding check

On the maintainer's machine the unqualified `/code-review` binds the built-in recall harness (empirically confirmed: its first step is a working-tree `git diff`, not a PR-number lookup). In a foreign / public install where the marketplace shadow could bind instead, detect it: if the invoked command demands a PR number rather than diffing the working tree, it bound the wrong instance → skip Phase 0, log `reason: /code-review bound marketplace shadow`, continue to Phase A. **Never pass a PR number to satisfy it.**

### Feed into the loop — correctness only (avoid double work)

Phase 0 exists for the recall the other phases lack: real bugs, **removed-behavior regressions**, and **broken call sites**, backed by the harness's independent verify step. Ingest ONLY those — findings whose `failure_scenario` is a concrete crash / wrong-output / data-loss / dropped-guard / broken-caller.

**Discard the rest at ingestion**, because other phases own those lanes and *act* on them:
- reuse / simplification / efficiency / altitude findings → **Phase B `/simplify`** (the same four angles, same lineage — `/simplify` and `/code-review` split from one command — and Phase B applies the fix, not just reports it). Re-acting here doubles the work.
- conventions / `CLAUDE.md` findings → **Phase A `code-reviewer`** (owns conformance + the Non-negotiables-always-BLOCK rule).
- correctness findings that overlap Phase A → dedup (same defect + location → keep one; Phase A wins, it adds plan-conformance / Non-negotiables context).

Surviving correctness findings enter **Round 1**'s fix loop, graded by `failure_scenario` (crash / wrong-output / data-loss / dropped-guard → critical or major BLOCK). Fixes go through the normal fix → `/check` cycle. Phase 0 is **not** re-run in later rounds.

### Compute note

`/code-review` is monolithic — it runs all eight angles, including the four cleanup ones whose output we discard. That wasted fan-out is the price of the verify step plus removed-behavior / cross-file recall that nothing else provides; `auto` effort keeps it bounded, and the harness ranks correctness first under its own output cap, so even a lower effort still surfaces the bugs we keep. If profiling later shows the duplicate cleanup fan-out dominates cost, the lever is to drop Phase 0's effort, not to also fix cleanup twice.

## Phase A rationale

**Why Phase A keeps a dedicated `code-reviewer` alongside Phase 0's `/code-review`.** Phase A's `code-reviewer` (`~/.claude/agents/code-reviewer.md`) is **not** replaced by the built-in `/code-review`: it owns plan-conformance anchoring and the rule "a `CLAUDE.md` Non-negotiables violation is always BLOCK regardless of confidence" — neither of which the generic `/code-review` performs. The recall the built-in harness adds (removed-behavior, cross-file, altitude, line-by-line correctness) is captured separately by **Phase 0**, deduped against Phase A, rather than by swapping Phase A's reviewer.

An earlier version of this gate omitted `/code-review` entirely, on the theory that "a third generic reviewer stacked on Phase A + Phase C only raises duplication." That was contradicted empirically — `/code-review` surfaces real findings the dedicated reviewer and the Phase C quartet miss (removed guards, broken call sites, bandaid-altitude fixes) — so per `~/.claude/CLAUDE.md` (empirical claims beat armchair theory) the harness is now wired in as a **deduped one-shot (Phase 0)**, not stacked per round. The `code-review:code-review` marketplace plugin remains avoided by name (it needs a PR number and reviews no working tree); Phase 0 binds the **core** built-in and degrades gracefully if a foreign install shadows it (see Phase 0 Binding check). The cloud `/code-review ultra` stays a manual pre-merge escape OUTSIDE this gate.
