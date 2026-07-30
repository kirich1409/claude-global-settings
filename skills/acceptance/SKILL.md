---
name: acceptance
argument-hint: "[slug] [--fix] [--levels L0,L1a,L2,L3,L4,L5] [--skip-levels …] [--reviewers …] [--base ref] [--max-rounds N]"
description: >
  The single post-implementation gate. Verifies an implementation against its verification
  contract (spec, test plan, or bug reproduction) by running the L0–L5 pyramid: a mechanical
  block, judgement layers, then device checks, aggregated into one receipt. Read-only by
  default — pass `--fix` to let it repair what it finds.
  Triggers: "acceptance", "verify this", "test this", "verify against spec", "QA the
  implementation", "run the test plan", "validate acceptance criteria", "verify the fix",
  "confirm bug is gone", "code quality pass", "polish the code", "prepare for review".
---

# Acceptance

Choreographer skill and the only mandatory gate after implementation. It executes a
pre-existing verification contract — it never invents checks. No contract → Step 1.5 halts and
names the upstream skill that produces one.

Pyramid levels L0–L5 are defined in `~/.claude/rules/qa-and-testing.md`; that file also fixes
the rule this skill depends on most — **a level says what must be proven, the project says what
proves it**. Acceptance derives every command it runs from the project at hand.

| File | Covers |
|---|---|
| [`references/source-branches.md`](references/source-branches.md) | Step 1 spec frontmatter and the four `test_plan_source` branches (receipt / mounted / on-the-fly / absent) |
| [`references/judgement-layers.md`](references/judgement-layers.md) | Block 2 — reviewer routing, security pattern triggers, coverage audit, fix loop and round budget, tolerance flags |
| [`references/subcheck-prompts.md`](references/subcheck-prompts.md) | Per-agent prompt contracts and output paths for every sub-check |
| [`references/aggregation.md`](references/aggregation.md) | Step 6 PoLL aggregation, Aggregated Status table, receipt template, downstream routing |
| [`references/re-verification.md`](references/re-verification.md) | Re-verification Loop `diff_hash` decision table and spec/test-plan change overrides |

---

## Inputs

Arguments arrive as one free-text string — parse it, do not expect positional substitution.
Everything is optional: with no arguments the gate runs the full pyramid for the slug it derives
from the branch. Unrecognised token → stop and say what was not understood; never guess.

**The gate is read-only by default.** It runs every level, reports every finding, and changes
nothing. Fixing is opted into with `--fix`, because an unasked-for fix is a change the caller
did not review — and on an unfamiliar repository a gate that rewrites working code to prove
itself is worse than a gate that reports.

| Argument | Effect |
|---|---|
| `<slug>` (first bare token) | Artifact family under `swarm-report/`. Default: branch name with a `feature/`, `fix/`, `chore/`, `refactor/`, `docs/` prefix stripped. |
| `--fix` | Enable mutation: the judgement fix loop repairs BLOCK findings and the coverage audit writes the missing tests. Without it both only report. |
| `--levels <list>` | Run exactly these pyramid levels. `L0,L1a,L2` = mechanical only; `L1b` = judgement only; `L3,L4,L5` = device only. Any level not listed is `SKIPPED` with `blocked_on: excluded by --levels`. |
| `--skip-levels <list>` | Subtractive form of the same knob — everything except these. Mutually exclusive with `--levels`; both given → stop and ask which was meant. |
| `--reviewers <list>` | Force these judgement reviewers regardless of their triggers, e.g. `security-expert,ux-expert`. Additive: triggered reviewers still run. |
| `--skip-reviewers <list>` | Suppress these reviewers even when triggered. Each suppression is recorded as an acknowledged risk with the caller's reason. |
| `--source <path>` | Use this file as the verification source instead of probing. Skips the Step 1 probe, not Step 1.5's requirement that a source exist. |
| `--base <ref>` | Diff base for every diff-derived trigger and for `diff_hash`. Default: merge-base with the remote default branch. |
| `--max-rounds N` | Judgement fix-loop budget, default 3. Meaningful only with `--fix`; given alone it is a no-op and worth saying so rather than silently ignoring. |
| `--coverage-audit` / `--skip-coverage-audit` | Force or suppress the coverage audit. |
| `--skip-security-review` | Turn off both the frontmatter and the diff-pattern security triggers. Discouraged. |

**A flag narrows scope, it never changes a verdict.** Every excluded level, suppressed reviewer
and skipped audit appears in the receipt under `acknowledged risks` with the argument verbatim
and the caller's reason — an excluded level is a tracked exception, never a silent pass. When a
flag excludes a level that `~/.claude/rules/qa-and-testing.md` marks mandatory for this task type
(L5 for version bumps, migrations, infra-layer changes, "must not change behavior"), say so
explicitly at the start of the run and require the caller to confirm.

**L0 cannot be excluded.** It is the implicit input gate of every other level: nothing is proven
about code that does not build.

---

## Execution model — three blocks

The pyramid answers "what must be proven", not "in what order processes run". Execution splits
into three blocks; the contract axis (conformance to the source of truth) runs across all three.

1. **Mechanical block** — L0 build, L1a lint and typecheck, L2 isolated tests, then the
   public-API coverage gate. Machine verdicts, fail-fast, no judgement.
2. **Judgement layers** — L1b. `code-reviewer` plus a conditional expert panel and the coverage
   audit, on top of a green mechanical block. Under `--fix`, **the mechanical block is re-run
   after every mutation**; that interleave is load-bearing, not a detail, because a fix that
   breaks the build invalidates every judgement made after it.
3. **Device block** — L3 UI tests → L4 E2E → L5 manual verification, strictly in that order.
   The gate owns the device and the installed build for the whole block.

Blocks are ordered. A red mechanical block never fans out to judgement; a failing judgement
layer with unresolved BLOCKs never proceeds to the device block.

---

## Vocabulary

Canonical values; `create-pr` and every downstream consumer read them from the receipt.

- **`project_type`** — `android | ios | web | desktop | backend-jvm | backend-node | cli |
  library | generic`.
- **`has_ui_surface`** — derived from `project_type`. True for `android`, `ios`, `web`,
  `desktop`; `generic` → ask the user.
- **`ecosystem`** — build stack (`gradle | node | rust | go | python | xcode`), used only to
  select mechanical-block commands. Orthogonal to `project_type`.
- **Per-check verdict** — `PASS | WARN | FAIL | SKIPPED`, plus `severity`
  (`critical | major | minor`), `confidence` (`high | medium | low`) and `domain_relevance`
  for aggregation.
- **Finding grade** — judgement findings are graded on the 0–100 confidence rubric defined
  once in `~/.claude/agents/code-reviewer.md` and inherited everywhere. **BLOCK** =
  critical/major ≥ 75. **WARN** = minor ≥ 50, reported only. Below threshold → dropped.
- **Aggregated Status** — `VERIFIED | FAILED | PARTIAL`.
- **Pyramid levels** — `L0` build, `L1a` static analysis, `L1b` expert agent review, `L2`
  isolated tests, `L3` integration, `L4` E2E, `L5` manual verification. Defined once in
  `~/.claude/rules/qa-and-testing.md`; `--levels` and `--skip-levels` address them by these names.

---

## Step 0: Detect Project Type

Detect from build files, manifests, and source layout: Android (`AndroidManifest.xml`,
`build.gradle*` with `com.android.application`), iOS (`*.xcodeproj`, `Package.swift` with iOS
targets), web (`package.json` with a browser-targeted framework), desktop (Compose Desktop,
Tauri, Electron), backend (Spring/Ktor/Express without UI), CLI / library (no UI surface).
Ambiguous → ask. Output: `project_type`, `has_ui_surface`, `ecosystem`.

**Override policy.** Non-empty spec frontmatter `platform:` wins — take its first value as
`project_type`, record the full list as `platforms: [...]`, never invent a `multi-platform`
type. Record `project_type_override: spec`, or `user` if corrected mid-run.

Step 0 and Step 1 file reads are disjoint — issue both sets in one batched Read call set.

---

## Step 1: Gather Inputs

Acceptance requires at least one verification source. Read spec sources (Figma, PRD, AC list,
PR description, issue) and load the spec frontmatter (`platform`, `surfaces`, `risk_areas`,
`non_functional`, `acceptance_criteria_ids`, `design.figma`).

Probe artifacts in a single batched Read call set: `swarm-report/<slug>-test-plan.md`,
`docs/testplans/<slug>-test-plan.md`, `swarm-report/<slug>-debug.md`.

The selected source fires one of four branches — `test_plan_source: receipt | mounted |
on-the-fly | absent`. `debug.md` as the only source qualifies Branch 3 (`on-the-fly`): bug-fix
verification treats it as a spec-like input. Branch semantics, mount-receipt overrides, and the
`surfaces` invariant guards live in
[`references/source-branches.md`](references/source-branches.md). Record the branch in the
receipt.

**Instrumentation verification.** When the test plan carries a `## Non-functional /
Instrumentation` section that is present and not `N/A: <reason>`, verify against the running
app that each declared event, metric, or span fires when its behavior runs. Declared but not
emitted, or emitted with wrong fields → P1 finding routed through the normal FAILED loop.

---

## Step 1.5: Source-Missing Gate

Fires only on `test_plan_source: absent`.

| Situation | Proposal |
|---|---|
| No spec, no test plan (feature) | `/write-spec` for the requirements, then re-run |
| Spec without AC, no test plan, UI project | Add AC to the spec, or `/write-plan --test-plan` for executable TCs |
| Bugfix without reproduction notes | Capture root cause + reproduction in `swarm-report/<slug>-debug.md`, then re-run |
| Only `design.figma`, no test plan, UI project | Design-only review via `ux-expert`; functional acceptance needs AC in the spec first |

Options: create the missing source via the named upstream skill and re-run, or abort without a
receipt. Exploratory QA without a scenario is `manual-tester` called directly — never offered
as a fallback inside acceptance.

---

## Step 2: Persist E2E Scenario

Only when `has_ui_surface == true` and a scenario source exists. Save to
`swarm-report/<slug>-e2e-scenario.md` using the canonical template in
`~/.claude/rules/context-resilience.md`, adding `Project type:` and `Spec source:` at the head.
`manual-tester` re-anchors against this file; acceptance writes it and re-reads it during
aggregation. The running-app environment is owned by `manual-tester` — this skill never probes
devices, installs builds, or starts dev servers.

Bug-fix rule: steps are the `debug.md` reproduction inverted — "Step X triggers the bug"
becomes "Step X no longer triggers the bug".

---

## Step 2.5: Persist Run State

Save the plan and compaction-resilient progress to
`swarm-report/<slug>-acceptance-state.md` — operational state, never a receipt. Write it after
all conditional triggers resolve and before the first agent spawns.

```markdown
# Acceptance State: <slug>

Status: planning | mechanical | judgement | device | aggregating | done
Arguments: <the argument string verbatim, or `none`>
Levels: <resolved level set after --levels / --skip-levels>
Cycle: <N> of 3              # incremented on Re-verification Loop re-entry
Round: <N> of <max-rounds>   # judgement-layer fix rounds
Started: <ISO8601>
Base: <base-branch>
Diff hash: <sha256 of git diff <base>...HEAD>
Spec hash: <sha256 of spec file, or null>
Test-plan hash: <sha256 of permanent test plan, or null>

## Planned Checks
- [ ] mechanical (always)
- [ ] code (always)
- [ ] ac-coverage (triggered by spec.acceptance_criteria_ids)
- [ ] security (triggered by risk_areas: [auth])
- [ ] manual (triggered by has_ui_surface + scenario)

## Completed Checks
- [x] mechanical — swarm-report/<slug>-acceptance-mechanical.md — PASS

## Aggregated Verdict History
### Cycle 1
Verdict: FAILED
Blockers: <copy from aggregated receipt>
```

Re-read before every major action (spawning a batch, aggregating, writing the receipt).
Completed `[x]` checks are never re-spawned after a compaction. Mark each `[x]` with artifact
path and verdict as soon as its file is written. On Re-verification Loop re-entry: increment
`Cycle`, reset `Planned Checks` from the new hashes, move reused checks under
`## Re-used from previous cycle`, append to the verdict history. `Status: done` makes the file
read-only history.

---

## Step 3: Mechanical Block (L0, L1a, L2)

Derive the commands from the project, in this priority order:

1. Explicit project instruction — its `CLAUDE.md`, the task plan, a documented `check` target.
2. Inferred from the stack — the build tool's aggregate task (`./gradlew check`,
   `npm test && npm run lint`, `cargo test && cargo clippy`, `swift build && swift test`,
   `make check`), detected linter and typechecker configs, existing test layout.
3. Neither yields a command → say so explicitly and record a tracked exception with the reason.
   Never silently treat a level as inapplicable.

Run build → lint/typecheck → isolated tests as one fail-fast sequence, then the **public-API
coverage gate** from `~/.claude/rules/qa-and-testing.md` §Gate покрытия public API: every
changed public symbol whose behavior or signature changed is matched to a test, or marked
trivial. An unmatched symbol is a BLOCK handled by the coverage audit in Block 2.

Non-code artifacts get the same levels with a different composition — for configuration, L0 is
"the file parses" and L1a is its schema or `validate-config`; a valid-looking diff is not a
verification.

Write `swarm-report/<slug>-acceptance-mechanical.md`. **Red block → stop and report**, with or
without `--fix`. Judgement layers do not run on code that does not build, and making a broken
build green is implementation work, not acceptance: `--fix` repairs findings the gate raised, it
does not finish someone's unfinished change.

---

## Step 4: Judgement Layers (L1b)

Emit **one** message containing every triggered Agent call simultaneously. `code-reviewer`
always runs. Conditional experts fire on spec frontmatter **or** on diff patterns — the diff
path matters most, because bug fixes and unspec'd tasks carry no frontmatter to declare risk.

Routing tables, the security broad/narrow pattern tiers and their thresholds, the coverage
audit, and the fix loop with its round budget all live in
[`references/judgement-layers.md`](references/judgement-layers.md). Per-agent prompts live in
[`references/subcheck-prompts.md`](references/subcheck-prompts.md).

**Diff detection — two cached passes**, alive for the whole run, never re-probed per agent:

1. **Path pass** — `git diff -M --name-only <base>...HEAD` once; drives every path rule.
2. **Content pass** — `git diff -M --unified=0 <base>...HEAD -- <cached-paths>` once, on first
   demand; drives every content rule. Content patterns match added/modified hunks only, so a
   pure rename cannot match them but can still match path patterns.

**Without `--fix`** there is no loop: findings are graded, written to their artifacts, and a
surviving BLOCK makes the aggregated status `FAILED`. **With `--fix`**, each mutation is followed
by a re-run of Step 3; the round ends when no BLOCK remains (→ Step 5) or the budget is exhausted
(→ ESCALATE, aggregated as `FAILED`).

### Per-check artifact schema

Each sub-check writes `swarm-report/<slug>-acceptance-<check>.md`:

```yaml
---
type: acceptance-check
check: mechanical | code | coverage | ac-coverage | design | a11y | security | performance | architecture | build-config | devops | ui-tests | e2e | manual
agent: <agent-name or "bash">
verdict: PASS | WARN | FAIL | SKIPPED
severity: critical | major | minor | null
confidence: high | medium | low | null
domain_relevance: high | medium | low | null
diff_hash: <sha256 of `git diff <base>...HEAD` when the check ran; null if the check does not depend on the diff>
blocked_on: <what the user must resolve; also used when a planned artifact is missing>
---
```

`severity`, `confidence` and `domain_relevance` are required for `WARN` and `FAIL`, null for
`PASS` and `SKIPPED`. One file per `check` value; an agent covering two concerns writes two
files. `diff_hash` is computed once per run and recorded identically by every check; a check
that writes `diff_hash: null` is never skipped by the Re-verification Loop on a hash match.

---

## Step 5: Device Block (L3, L4, L5)

Runs only when `has_ui_surface == true` and the judgement layers left no BLOCK. Strictly
ordered, because each level is more expensive and less precise than the one before it:

1. **L3 — UI / instrumentation tests.** The project's automated UI suite against a real
   runtime. No suite and no way to add one cheaply → tracked exception with the reason, not a
   silent skip.
2. **L4 — E2E.** Whole-scenario runs, when the project has them.
3. **L5 — manual verification.** `manual-tester` against `swarm-report/<slug>-e2e-scenario.md`.

**The device is an exclusive resource.** The gate owns it and the installed build for the whole
block: never run two device checks against one instance concurrently, and address the target
explicitly when several exist. `manual-tester` owns environment setup, cloning, and teardown
inside its own run.

L5 is mandatory — not optional — for library version bumps (patch included), tech and framework
migrations, infra-layer changes (network, storage, auth, DI), and any task claiming "this must
not change behavior". For a non-UI project L5 is still real execution: the hook fired, the rule
rejected the call, the fresh session came up clean.

---

## Step 6: Aggregate and Write Receipt

Apply the PoLL rules and the Aggregated Status table from
[`references/aggregation.md`](references/aggregation.md). Read each per-check artifact's
frontmatter first; read the body only when `verdict != PASS`. A missing artifact is
`verdict: FAIL` with `blocked_on: per-check artifact missing` — never silently dropped.

Save `swarm-report/<slug>-acceptance.md` from the template in the same reference. Post a chat
summary (≤20 lines); never paste receipt tables into chat — the file is the audit trail.

- **VERIFIED** — "N checks passed." Up to 3 bullets: what ran, what was skipped and why. Next
  step: `/create-pr`, or `/drive-to-merge` when a PR exists.
- **FAILED** — "N check(s) failed." Up to 5 bullets, one failure each. One question: fix and
  re-run, or ship accepting the risk.
- **PARTIAL** — "N passed, M inconclusive." Bullets: what was inconclusive and why. One
  question: proceed to PR or re-run the inconclusive checks.

---

## Re-verification Loop

On re-entry after a fix (`FAILED` → fix on the branch → re-run), compute `diff_hash_new` and
decide per check what to re-run and what to reuse, per the decision table in
[`references/re-verification.md`](references/re-verification.md). A `spec_hash` or
`test_plan_hash` mismatch forces `business-analyst` and `manual-tester` regardless of the diff.
Aggregate into a fresh receipt overwriting the previous one; repeat until VERIFIED or the user
decides to ship as-is.
