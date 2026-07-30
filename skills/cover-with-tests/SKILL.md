---
name: cover-with-tests
argument-hint: "<area> [--kinds unit,integration,ui-instrumentation,ui-scenario,screenshot,e2e] [--level L2] [--source path] [--regression] [--characterize]"
description: "Cover an area of a project with automated checks. Takes an area — a path, module, directory, symbol, layer, feature, or the current diff — investigates what it does and what already proves it, decides which kinds of checks at which pyramid level are needed, derives the framework from the project, delegates the writing to the engineer agent that owns the surface, and verifies the result. Stack-agnostic: the area, the kinds and the level are the vocabulary; what realizes them comes from the project. Also runs a red-green regression mode for a specific bug fix, and a characterization mode that pins current behavior when no specification exists. This is the skill that fills the `test-authoring-role` other skills hand work to — the migrate-code coverage-gap report and the /acceptance coverage audit. Use when: \"write tests for\", \"cover this with tests\", \"add tests to\", \"this module has no tests\", \"increase coverage\", \"characterize this legacy class\", \"add a regression test for this bug\", \"make this code verifiable\". Do NOT use for: a test plan document (use /write-plan --test-plan), running checks against a live app (use /acceptance), exploratory QA (call manual-tester directly), or tests that are part of a feature being built (the engineer agent writes those inline)."
---

# Cover With Tests

Given an **area** of a project, produce the automated checks that make that area verifiable.

Stack-agnostic by construction. The area, the **kinds** of check, and the **pyramid level** are the
vocabulary; what realizes them — framework, assertion library, doubles, runner — comes from the
project, discovered, never assumed. A stack this skill has never seen is a discovery problem, not an
out-of-scope one.

This skill **orchestrates**: it investigates, decides, delegates the writing, and verifies. It fills
the `test-authoring-role` that other skills hand work to — the coverage-gap report from
`migrate-code` and the coverage audit inside `/acceptance` both land here, so the
delegate-write-verify cycle has exactly one owner.

| File | Covers |
|---|---|
| [`references/test-infrastructure-discovery.md`](references/test-infrastructure-discovery.md) | Phase 4 detection tables per ecosystem and the Test Infrastructure Summary template |
| [`references/agent-prompts.md`](references/agent-prompts.md) | Phase 5 delegation prompt templates |

Adjacent ownership, not restated here: the kind-selection heuristic and the `Type` vocabulary live
in `write-plan/references/test-plan.md` §Type; pyramid levels in `~/.claude/rules/qa-and-testing.md`;
the seam trap and the golden-master semantics in `migrate-code/references/safety-net.md`.

**Author fixes broken tests** — `~/.claude/rules/qa-and-testing.md`. Skipping or ignoring a test
without a tracked follow-up in the annotation itself is not allowed.

---

## Inputs

| Argument | Effect |
|---|---|
| `<area>` | What to cover: a file path, directory, module, glob, symbol, layer, feature name, or `--diff` for the current change. A vague reference ("the auth module") is resolved via the code index, then `Grep`/`Glob`; still ambiguous → one question. |
| `--kinds <list>` | Restrict to these kinds: `unit`, `integration`, `ui-instrumentation`, `ui-scenario`, `screenshot`, `e2e`. Default: chosen per behavior in Phase 3. A stack may add its own kind (a DI-graph verification, a schema check) — name it explicitly in the report. |
| `--level L<n>` | Minimum pyramid level the result must reach. Maps to `judge_level` in a coverage-gap report. |
| `--source <path>` | The source of truth: a spec, a test plan, `swarm-report/<slug>-debug.md`, or a baseline. |
| `--from-report <path>` | A coverage-gap handoff report (`target`, `baseline`, `risk_rank`, `coupling`, `judge_level`, `test_type` — schema in `migrate-code/references/safety-net.md`). An accelerator, never a precondition: "characterize this class" with no report is a valid request. |
| `--regression` | Red-green mode for one specific bug: the result is a single check that fails on the unfixed code and passes with the fix. |
| `--characterize` | No specification exists — pin current behavior as a golden master. |

---

## Phase 1: Understand the area

Investigate before writing anything. Produce a **coverage assessment** with five outputs:

1. **What the area does** — entry points, public surface, observable effects (returned values,
   persisted state, emitted events, rendered output, network calls). Behavior that is not observable
   from outside cannot be asserted; name it now rather than discovering it in Phase 6.
2. **Boundaries** — what belongs to the area and what it collaborates with. Collaborators decide
   which kinds are even possible.
3. **What already proves it** — existing checks that reach this area, and how much of it they watch.
4. **Coupling of that coverage** — `agnostic` or `coupled`: whether the existing checks are welded
   to an implementation detail the area might change. Coupled coverage counts for less than its line
   count suggests, and this is the number that decides whether existing tests survive a rewrite.
5. **Seams and risk** — where a check can attach today, where it cannot, and a risk rank per
   behavior so Phase 3 can spend effort where failure costs most.

**Going outside the area is expected, not a scope violation.** Making an area verifiable routinely
requires a test harness, fixtures, fakes, a seam, or a sample application that hosts the surface
where it can be driven. Name what must be built outside the area as part of the assessment; building
it silently hides the real cost, and refusing to build it produces a plan that cannot run.

`--regression` narrows this phase to the one reported behavior: no coverage sweep, no ranking.

---

## Phase 2: Establish the source of truth

A check encodes a claim about correct behavior. Where that claim comes from decides what the check
is worth, so it is settled explicitly, never assumed.

| Situation | What to do |
|---|---|
| Passed in (`--source`, `--from-report`) | Use it. A report's `baseline` field carries the observable effects to pin — that is the one thing no other field supplies. |
| Discoverable | Gather it: a spec with AC, a test plan under `docs/testplans/`, `swarm-report/<slug>-debug.md`, an issue, a documented contract. |
| None exists | **Characterization.** Pin what the code does today. |

**Characterization is a recording, not a specification.** It has no authority over whether current
behavior is correct — it only fails when behavior changes. Say so in the report and in a header
comment on each generated file. A golden master silently read as "the tests say this is correct"
invites a genuine bug fix to be reverted later as a regression, which is a worse outcome than having
no check at all.

---

## Phase 3: Decide what to write

Per behavior worth proving, choose the **smallest kind that catches a real failure of it**, and
climb only when the smaller kind cannot. The kind table and its selection heuristic are defined once
in `write-plan/references/test-plan.md` §Type — apply it, do not restate a second vocabulary here.
`--kinds` and `--level` constrain the choice; when a constraint makes a behavior unprovable, say so
rather than writing a check that asserts something else.

**Seam discipline.** Getting code under test often needs a seam — an injection point, an extracted
interface, a parameter where a static call used to be. Creating that seam is a refactoring of code
that currently has no check on it, so it is a mini-migration and it recurses if allowed: the seam
needs a test, the test needs another seam, and the preparation eats the task. Three rules, from
`migrate-code/references/safety-net.md` §The seam trap:

- **Do not recurse.** A seam is justified when the compiler is a valid referee — extract an
  interface, add a parameter, lift an instantiation. A seam that itself needs a behavior judge is
  not a seam, it is a second job.
- **Budget it up front** and treat overrun as a signal, not an overspend to absorb.
- **When the budget is gone**, the honest outcomes are a coarser check one level up — assert where
  the system is already observable rather than where you wish it were — or stopping and reporting.
  Not a silent skip.

**Large area** — more than a handful of units to cover: present the ranked list with one line each
(risk, complexity, what is unobservable) and ask which subset to do now. Recommend the
highest-risk-first subset. Small area: proceed.

---

## Phase 4: Derive the stack

Read the project, in this order, stopping at the first step that answers definitely:

1. Existing checks in the module under change.
2. Test-related dependencies declared in the build configuration.
3. The framework the majority of the project's checks already use.
4. The ecosystem's conventional default — per-ecosystem tables in
   [`references/test-infrastructure-discovery.md`](references/test-infrastructure-discovery.md).

Then inspect three to five existing check files plus the build configuration and compile a **Test
Infrastructure Summary** — framework, assertion style, doubles, async helpers, UI stack, naming and
file placement — which Phase 5 passes to the writer verbatim. The goal is blunt: the result must
look hand-written by this project's authors.

**Never introduce a new framework or a new dependency to make a check possible.** Stop and ask.
Escalations: two frameworks in existing checks → follow the majority in the affected module, and on
an even split ask one question; the detected framework unavailable in the toolchain → fall back one
step and record the fallback in the Summary and in a header comment; a required dependency missing
entirely → stop and ask.

---

## Phase 5: Write

Delegate to the engineer agent that owns the surface — routed by the language and the layer, so a
UI surface and a logic surface in one area go to two agents. The prompt carries the area paths, the
Phase 2 source of truth, the Phase 3 decisions, the Phase 4 Summary, and a style-reference file;
templates in [`references/agent-prompts.md`](references/agent-prompts.md).

**No engineer agent covers this stack** — the main session writes the checks itself, using the
Phase 4 Summary as its own brief. This is a degraded but supported mode, not a stop: automated
authoring exists on some stacks and not others, and the role is filled either way.

---

## Phase 6: Verify

**`--regression` first: prove the check would have failed.** A regression check written after the
fix is green by construction and may assert something that was already true before the fix.

1. Identify the fix commits: `git log <base>..HEAD --pretty=format:"%H" -- <fixed-files>` is
   authoritative; a caller-supplied hint (a `Commit` field in `debug.md`, hashes given in chat)
   narrows the set.
2. Revert them without committing — `git revert <hash> --no-commit`, `-m 1` for a merge commit,
   newest first for several. A conflict is resolved **toward the buggy side**
   (`git checkout --theirs <file>`); resolving toward the fix produces a false green.
3. Run only the new check, with the narrowest filter the project's runner offers.
4. **RED** → contract verified. `git reset --hard HEAD` restores tracked files while leaving the
   new, still-uncommitted check in place. Record one line in the receipt:
   `Regression contract: VERIFIED — RED on revert of <hashes>, GREEN with fix.` Continue.
5. **GREEN on the unfixed code** → the check does not capture the regression. It is structurally
   wrong and is not salvaged: discard the revert **and** the check
   (`git reset HEAD -- . && git checkout -- . && git clean -fd`), then produce the Coverage
   Diagnosis below and return `INEFFECTIVE`. Do not run the suite.

Then run the checks with the project's own runner. Classify every failure:

| Failure | Action |
|---|---|
| **Check bug** — wrong assertion, wrong setup, missing double | Fix via the same writer, at most 3 attempts |
| **Production bug** — the check correctly exposes a real defect | Do **not** fix. Record as a finding. |

Distinguish by reading the assertion against the code: expectation contradicts behavior that looks
intentional → check bug; expectation matches the documented contract that the code violates →
production bug. Unclear → report it as a finding rather than silently changing the assertion to
match the code, which converts a real defect into a passing check.

Still failing after 3 attempts → Coverage Diagnosis, stop, report.

In `--regression` mode only, commit and push the check once green, so it lands on the branch as part
of the bug-fix work: `git commit -m "Add regression test: <scenario>"`. The message names the
scenario — it is the permanent explanation of why the check exists. Other modes leave file
management to the caller.

---

## Phase 7: Report

Files created with per-file counts · what is now provable that was not before, and what was left
uncovered with the reason · results · findings.

**Production bugs** → `swarm-report/<slug>-test-findings.md`, one entry each with location,
what the code does, the expected behavior, the check that exposed it, and severity. Written only
when real defects were found — otherwise the checks themselves are the artifact.

**Coverage Diagnosis** → `swarm-report/<slug>-coverage-diagnosis.md`, when the work could not be
completed: an ineffective regression check, failure after 3 attempts, or a behavior that could not
be covered at all.

```markdown
# Coverage Diagnosis: <slug>

Date: <YYYY-MM-DD>
Status: INEFFECTIVE | FAILED | NOT_ATTEMPTED

## What was tried
<the approach and the assertion, or why nothing was written>

## Technical obstacle
<the specific reason — "the assertion targets the return value but the bug is a side effect on a
non-injectable static", "the reproduction needs two threads interleaving and the test dispatcher
serialises them", "the path is behind a native call with no double". Never "the test failed".>

## To make it testable
<what would have to change in the code or the setup>
```

A diagnosis is a result, not a failure to report: it converts "we have no coverage here" from a
silence into a tracked, actionable item. Reference it in the PR body.

---

## Disambiguation

- **Intentional behavior change** — a new check asserts a different outcome than an existing one:
  update the older check in the same run with a one-line comment naming the new contract.
- **Unintentional break** — a previously green check fails after this work and should not have been
  affected: the change is wrong, revise it.
- **Already red on the base branch** — out of scope; report it and continue.
