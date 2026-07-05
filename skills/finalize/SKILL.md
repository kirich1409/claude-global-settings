---
name: finalize
description: >
  Run a code-quality pass over the current branch — multi-round review-and-fix loop that
  polishes how the code is written, not what it does. Runs a one-shot built-in /code-review
  deep scan, then code-reviewer, /simplify, optional pr-review-toolkit quartet, and conditional
  expert reviews with /check between rounds; exits PASS when no BLOCK findings remain or ESCALATE after max rounds.
  Triggers: "finalize", "run code quality pass", "clean up the code", "prepare for review",
  "polish the code", "tidy up", "harden the implementation".
---

# Finalize

Code-quality pass over the current branch. Multi-round review-and-fix loop focused on **how** the code is written (quality, clarity, robustness), not **what** it does (functional acceptance, owned by `acceptance`) or **whether it works** (build/lint/tests, owned by `/check`).

`finalize` orchestrates a one-shot built-in `/code-review` deep scan + `code-reviewer` + `/simplify` + the optional `pr-review-toolkit` quartet + conditional expert reviews — none of those alone catches the full set of recurring patterns (removed-behavior regressions, cross-file breakage, wrong-altitude bandaids, over-engineered abstractions, silent failures, fragile types, weak coverage).

**Author fixes broken tests** is enforced per `~/.claude/rules/qa-and-testing.md` § 4. A `/check` between phases that surfaces test failures triggers an inline fix in the same round — owned by the engineer agent that produced the change. Round-end exit is impossible while tests remain red.

Procedural detail lives in reference files loaded only when the corresponding phase runs. SKILL.md stays the stable orchestration contract.

| File | Covers |
|---|---|
| [`references/phases.md`](references/phases.md) | Phase 0 deep-scan effort-selection table, binding-check fallback, ingestion/discard rules, compute-cost note; Phase A rationale for keeping a dedicated `code-reviewer` alongside Phase 0 |
| [`references/reviewer-matrix.md`](references/reviewer-matrix.md) | Phase C `pr-review-toolkit` quartet table; Phase D expert-trigger matrix, `security-expert` pattern triggers, handling of expert findings, `test-coverage-expert` conditional + `coverage-audit.md` schema |
| [`references/receipts.md`](references/receipts.md) | `<slug>-finalize.md` report template, `<slug>-quality.md` receipt schema, chat-summary formats |

---

## Inputs

- **`slug`** — task slug for artifact naming.
- **Branch state** — reads the current branch; never switches.
- **Context artifact (optional)** — Phase A `code-reviewer` anchor: feature plan (`docs/plans/<slug>/plan.md`, written by `write-plan`; falls back to legacy `swarm-report/<slug>-plan.md`) or, for bug fixes, debug artifact (`swarm-report/<slug>-debug.md`).
- **Diff artifact (derived)** — before invoking `code-reviewer`, materialize the diff to `swarm-report/<slug>-diff.txt`. Do not hardcode `origin/main`: derive the remote's default branch (same as `create-pr` — `git remote show origin | grep "HEAD branch" | awk '{print $NF}'`, fallbacks `main` / `master` / `develop`), then `git merge-base origin/<base> HEAD`.

**Tolerance flags (optional):**

- `--allow-warn` — stop after 1 round on WARN-only (default: PASS on WARN-only, keep iterating BLOCKs).
- `--deep-scan-effort <auto|low|medium|high|xhigh|max>` — effort for the Phase 0 `/code-review` deep scan (default `auto`: scaled from the diff's risk signals — see Phase 0 § Effort selection). Pin an explicit level to override the auto choice in either direction.
- `--skip-deep-scan` — omit Phase 0 entirely (recorded verbatim in `acknowledged risks`). Phase 0 also auto-skips on trivial diffs.
- `--skip-experts` — omit Phase D (rarely useful; experts auto-skip when no triggers match).
- `--max-rounds N` (≥ 1) — override the default 3. Use after an ESCALATE for one more round without restarting.
- `--coverage-audit` / `--skip-coverage-audit` — force-on / force-off Phase D `test-coverage-expert`. Skip is discouraged; recorded verbatim in `acknowledged risks`.
- `--skip-security-review "<reason>"` — disable both `risk_areas` and pattern triggers for this round. Reason captured verbatim. Discouraged; other Phase D experts still fire.

---

## Round structure

Phase 0 runs **once**, before the loop. Then each round runs phases A → B → C → D sequentially. Between phases and after any auto-fix, invoke `/check`. Accumulate findings; at round end, exit or continue.

```
Phase 0 (once, pre-loop) → built-in /code-review deep scan → dedup vs Phase A → feed Round 1
Round N:
  A  → code-reviewer          → fix BLOCK → /check
  B  → /simplify (auto-fixes) → /check
  C  → pr-review-toolkit quartet (parallel, if installed) → fix BLOCK → /check
  D  → expert reviews (conditional, parallel)          → fix BLOCK → /check
  Any unfixed BLOCK → round N+1 (up to max_rounds, default 3); else PASS
```

**Exit criteria.** PASS — no BLOCK findings; WARN / NIT listed in report, never block. ESCALATE — after `max_rounds`, BLOCKs remain; dump unresolved findings, caller decides override or return to implementation.

**Max round budget.** Default 3, overridable via `--max-rounds N` (≥ 1). Regularly hitting the cap means Phase A's `code-reviewer` confidence threshold should be tuned (`~/.claude/agents/code-reviewer.md`), not `max_rounds` silently raised.

---

## Phase 0 — Deep scan (built-in `/code-review`, one-shot)

Runs **once per finalize run, before Round 1** — not per round. Captures the **correctness recall** the built-in `/code-review` harness provides and the other phases do not: line-by-line bug scan, removed-behavior auditing, and cross-file tracing, backed by an independent verify step. That recall comes from the harness's multi-angle fan-out + verify — paraphrasing its angle names into another agent's brief does **not** substitute for running it, so the real command is wired in rather than imitated. Its cleanup/altitude/conventions angles overlap Phases B and A and are discarded at ingestion (see [references/phases.md § Feed into the loop](references/phases.md#feed-into-the-loop--correctness-only-avoid-double-work)) — Phase 0 is a correctness layer, not a cleanup one.

**Skip when the diff is trivial** (same bar as `test-coverage-expert`): single file, < 50 LOC, refactor-only, no new public API. Log `phase: 0, status: skipped, reason: trivial diff`. Also skipped by `--skip-deep-scan` (logged in `acknowledged risks`).

**Invocation.** Invoke the **built-in** `/code-review` — the core skill, unqualified name `code-review`, NOT the `code-review:code-review` marketplace plugin (which needs a PR number and cannot review a working tree) — in **report mode** against the branch diff:

- effort from `--deep-scan-effort` (default `auto`, resolved in [references/phases.md § Effort selection](references/phases.md#effort-selection-auto)); **no `--fix`** (severity triage is owned by finalize's fix loop, not the harness), **no `--comment`** (this gate runs pre-PR on a working tree).
- The harness reviews the current-branch diff + uncommitted changes and returns a JSON array of findings (`file`, `line`, `summary`, `failure_scenario`), most-severe first.

Full effort-selection table, binding-check fallback, ingestion/discard rules, and the compute-cost note: [references/phases.md § Phase 0](references/phases.md#phase-0--deep-scan-detail).

---

## Phase A — Semantic review (code-reviewer)

Launch `code-reviewer` (`~/.claude/agents/code-reviewer.md`) with task description verbatim, plan artifact path (`docs/plans/<slug>/plan.md`, else legacy `swarm-report/<slug>-plan.md`) if it exists, and `git diff` of all branch changes. Returns PASS / WARN / FAIL with findings on the 0/25/50/75/100 confidence rubric (only above-threshold findings surface).

Non-negotiables violations from applicable `CLAUDE.md` `## Non-negotiables` are always BLOCK regardless of confidence — never moved to "acknowledged risks".

| Severity × confidence | Action |
|---|---|
| critical ≥ 75 | Fix immediately, re-run `/check`. PASS + resolved → BLOCK cleared. Doesn't converge → stays BLOCK, round ends without PASS. Never silently downgrade to "acknowledged risk". |
| major ≥ 75 | Fix if tractable. Refactor beyond diff → escalate; remains BLOCK until caller resolves or moves to "acknowledged risks" at ESCALATE. |
| minor ≥ 50 | NIT in report. Don't auto-fix; never blocks PASS. |

FAIL verdict → this phase has BLOCKs to address before continuing.

Rationale for keeping a dedicated `code-reviewer` alongside Phase 0's `/code-review` deep scan, and why an earlier version that dropped it was reverted: [references/phases.md § Phase A rationale](references/phases.md#phase-a-rationale).

---

## Phase B — Built-in simplification (`/simplify`)

Invoke `/simplify`: parallel reuse / quality / efficiency pass that **applies fixes directly**. Treated as a behavioural contract; internal structure may evolve. Coverage: reuse (duplicated logic), quality (redundant state, parameter sprawl, leaky abstractions, stringly-typed, unnecessary comments), efficiency (redundant work, missed concurrency, hot-path bloat, TOCTOU, leaks). Don't pre-review output — trust it, then `/check`.

**On `/check` FAIL after `/simplify`:** revert the simplify commits (or the last commit if unambiguously from `/simplify`), log `phase: B, reason: revert`, continue to Phase C. Do not re-invoke `/simplify` in the same round.

**Round-budget semantic.** Phase B is transformative, not a finding-generator. A revert does NOT introduce an unresolved BLOCK and does NOT consume budget — the round continues through C and D. Distinct from `/check` failure after Phase A/C/D fix (§Mechanical verification), where the originating finding stays BLOCK.

---

## Phase C — PR review toolkit (parallel, optional)

Soft-reference to `pr-review-toolkit` (marketplace `claude-plugins-official`). Not a hard dep — that marketplace publishes plugin entries without `version` fields, breaking semver resolution.

Before invoking, check whether the `pr-review-toolkit` agents are available (e.g. Task agent registry). Any missing → skip Phase C, log `phase: C, status: skipped, reason: pr-review-toolkit not installed`, continue to Phase D. Otherwise invoke the applicable agents in **parallel** — full per-agent table (focus + fire conditions): [references/reviewer-matrix.md § Phase C](references/reviewer-matrix.md#phase-c--pr-review-toolkit-quartet).

Findings graded on the same 0–100 rubric as `code-reviewer` (inherited via prompt sharing). Apply Phase A fix-loop: BLOCK (critical/major ≥ 75) → fix → `/check`; WARN (minor ≥ 50) → report only; below threshold → drop. Test-quality fixes that need new test code → delegate to the matching engineer agent.

---

## Phase D — Expert reviews (conditional, parallel)

Trigger experts only when the diff matches their domain. Launch the matching ones in **parallel**. No trigger matched → skip Phase D entirely for this round.

Full expert-trigger matrix (architecture / security / performance / ux / build / devops / business-analyst / test-coverage-expert), the `security-expert` pattern-trigger table + threshold rules, handling of expert findings, and the `test-coverage-expert` conditional (trigger/skip rules + `coverage-audit.md` schema): [references/reviewer-matrix.md § Phase D](references/reviewer-matrix.md#phase-d--expert-review-matrix).

---

## Mechanical verification between phases

After **any** code modification within a round, re-invoke `/check`. On FAIL:

1. Log which phase's fix introduced the failure.
2. Narrow repair — **1 attempt max**. At finalize stage the code already passed `/check` once, so a regression signals the fix itself was wrong; retrying compounds rather than converges.
3. Still failing → revert the fix and keep the originating finding **as BLOCK** for the round (not resolved, counts against budget). Continue remaining phases; never relabel a reverted BLOCK as "acknowledged risk".
4. Round ends with unresolved BLOCKs → next round. Round 3 ends with unresolved BLOCKs → ESCALATE.

Do not let `/check` failures cascade, and do not use revert-and-continue to silently ship a BLOCK.

---

## Report

Save `swarm-report/<slug>-finalize.md` (round-by-round detail log) and `swarm-report/<slug>-quality.md` (terse receipt consumed by `acceptance` Step 2.5 and `create-pr`'s status table) on exit (PASS or ESCALATE). Templates, verdict mapping, and chat-summary formats (PASS / ESCALATE): [references/receipts.md](references/receipts.md).

Never paste the report table into chat — the file is for reference.

---

## Scope and escalation

- **In scope:** improving quality of code *related to the current diff*; delegating fixes to engineer agents; `/check` after each mutation.
- **Out of scope:** new features, scope changes, functional acceptance, architectural redesign.
- Keep fixes inside files touched by the original change. Adjacent-file edits only when a finding explicitly requires them (e.g., `pr-test-analyzer` adding a sibling test, `/simplify` extracting a helper).
- Never re-scope under "cleanup" — structural issues beyond narrow-fix reach escalate.
- Never silently skip Phase A — `code-reviewer`'s plan-conformance check is the anchor. If it fails to launch for infrastructure reasons, stop and escalate.

**Escalate (stop and report) when:** unresolved BLOCKs after `max_rounds`; `/check` fix doesn't converge after 1 retry; BLOCK requires refactoring beyond diff scope; expert finding demands architectural change; required engineer agent (e.g. `kotlin-engineer`) is not installed but needed for a fix. State which phase escalated, what is unresolved, and what the caller must decide.

---

## Dependencies

- **Hard:** local agents in `~/.claude/agents/` — `code-reviewer.md`, `security-expert.md`, `performance-expert.md`, `architecture-expert.md`.
- **Optional soft-ref** (Phase C auto-skips when absent): `pr-review-toolkit` (marketplace `claude-plugins-official`) — `pr-test-analyzer`, `silent-failure-hunter`, `type-design-analyzer` (always), `comment-analyzer` (only when the diff touches comments / doc-comments).
- **Built-in:** `/code-review` (core recall harness — Phase 0; degrades gracefully if a marketplace shadow binds instead), `/simplify`, `/check`.
