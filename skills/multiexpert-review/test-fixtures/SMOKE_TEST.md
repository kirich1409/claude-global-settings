# multiexpert-review — smoke-test harness

Lightweight manual-run smoke-test for the `multiexpert-review` skill. Verifies that each profile activates correctly and produces structurally valid output.

## Scope

This harness checks **structural** properties, not content-level correctness. Because PoLL is stochastic, content of individual issues will differ run-to-run. Structural invariants are stable and what we assert against.

## Fixtures

| Fixture | Expected profile | Expected behavior |
|---------|------------------|-------------------|
| `plan.md` | `implementation-plan` | Tech-match agent selection; verdict alphabet `PASS/CONDITIONAL/FAIL` |
| `test-plan.md` | `test-plan` | Roster includes `business-analyst`; verdict alphabet `PASS/WARN/FAIL`; review prompt augmented with the 7-item checklist (a)–(g) |
| `upstream-plan.md` + `upstream-spec.md` | `implementation-plan` | Upstream detector fires: `{UPSTREAM_DOCUMENT}` filled from `spec:`, at least one finding with `scope: upstream`, escalation type `upstream_defect`, cycle aborted **without** a fix round on the plan |
| `plan.md` (no `spec:`) | `implementation-plan` | Upstream detector stays silent: `{UPSTREAM_DOCUMENT}` empty → every finding `local`, ordinary FAIL/CONDITIONAL cycle. Negative control for the detector |
| `spec.md` | `spec` | Roster = `[business-analyst, architecture-expert]`; verdict alphabet `PASS/CONDITIONAL/FAIL`; severity mapping uses rubric-item keys (`acceptance_criteria`, `prerequisites`, `out_of_scope`, etc.) |
| `unknown-artifact.md` | (none — ask user) | Detector falls through all four stages; engine returns profile-choice prompt to user, does not silently default |

## Running a smoke-test manually

1. Pick a fixture, e.g. `plan.md`.
2. Invoke `multiexpert-review` in a Claude Code session on the fixture. For `spec.md`, you can either rely on frontmatter detection or prepend `profile: spec\n---\n` hint (the `write-spec` callsite does the latter for in-memory drafts — see `write-spec/SKILL.md` section 4.3 "Run multiexpert-review (spec profile)").
3. Capture the **structural** properties of the run (not the content of individual issues):
   - Which profile the engine detected (logged in state file under `Profile:` and `Profile source:`)
   - Reviewer roster actually invoked
   - Verdict label chosen from the profile's alphabet
   - Whether a receipt was written (only the `test-plan` profile has a `receipt:` section)
   - Error prefix if any (e.g. `[multiexpert-review ERROR] UNKNOWN_PROFILE_HINT: ...`)
4. Compare observed structural properties to the expectations table above.

## Expected outcomes per fixture

### `plan.md` (implementation-plan)

- **Profile detected:** `implementation-plan`
- **Profile source:** `frontmatter` (from `type: plan`)
- **Reviewer roster:** derived by tech-match selection; for this fixture typically at least one of `architecture-expert` (cache layer → architecture), `build-engineer` (Gradle / Redis client dep), `devops-expert` (Helm / deployment)
- **Verdict:** one of `PASS / CONDITIONAL / FAIL`
- **Receipt:** none (implementation-plan profile omits `receipt:`)

### `test-plan.md` (test-plan)

- **Profile detected:** `test-plan`
- **Profile source:** `frontmatter` (from `type: test-plan`)
- **Reviewer roster:** `business-analyst` (always); plus `security-expert` if fixture mentions `auth|token|encryption|PII|credential` (this fixture does not); plus `performance-expert` because fixture mentions `latency` and `p99` (matches `SLA|latency|throughput|budget`)
- **Verdict:** one of `PASS / WARN / FAIL`
- **Receipt writing:** under engine orchestration, `receipt.path_template` resolves to `swarm-report/smoke-test-test-plan-fixture-test-plan.md` and the engine **creates or updates** that file with `review_verdict` + optional `review_warnings` / `review_blockers`. If you run this fixture via the real engine, expect a new or updated file at that path. If you capture baseline via direct-agent invocation (the mode used in `baseline-results.md`), no receipt is written because the engine is bypassed.
- **Rubric applied:** 5-item checklist (a)–(e) must be evaluated explicitly

### `spec.md` (spec)

- **Profile detected:** `spec`
- **Profile source:** `frontmatter` (from `type: spec`) OR `path_glob` if placed under `docs/specs/**`
- **Reviewer roster:** `[business-analyst, architecture-expert]` (mandatory primary per profile)
- **Verdict:** one of `PASS / CONDITIONAL / FAIL`
- **Severity mapping:** issues titled with rubric-item keys (`acceptance_criteria`, `prerequisites`, `out_of_scope`, `decisions_made`, `affected_modules`, `open_questions_tagged`, `technical_approach_detail`)
- **Expected findings:** this synthetic spec is deliberately skeletal → reviewers should find critical violations of `acceptance_criteria` (ACs like "works", "fast enough" are not observable/verifiable) and major violations of `decisions_made` (no rationale) and `affected_modules` (vague)

### `unknown-artifact.md` (no profile)

- **Profile detected:** none
- **Detector path:** all four stages fall through (no hint, no frontmatter, no path glob match, no structural signatures)
- **Expected engine behavior:** prompt user with `AskUserQuestion` listing `PROFILE_INVENTORY = [implementation-plan, test-plan, spec]`. **Never** silent fallback to implementation-plan.
- **Verdict:** N/A until user selects a profile

### `upstream-plan.md` + `upstream-spec.md` (upstream detector)

The only executable check on the rollback protocol. The plan is deliberately well-written; the defects
sit in the spec it links to, so a fix cycle on the plan cannot close them — the failure mode the
detector exists to prevent.

- **Prompt:** the review prompt must contain a `## The Upstream Document (upstream-spec.md)` section
  with the spec's full text. Absent → the detector is misconfigured, and everything below is void.
- **Expected findings:** at least one `scope: upstream` with a location inside `upstream-spec.md`
  (AC-1 platform restriction, or the AC-2/AC-3 contradiction) and a verbatim quote from that file —
  never from the plan's own restatement.
- **Expected engine behavior:** verification step first (`spike-runner` / `hard-case-arbiter`), then
  escalation `upstream_defect`; the plan is **not** edited, the cycle counter does not advance to a
  fix round. Class assigned at synthesis: `infeasible` for AC-1, `contradictory` for AC-2 vs AC-3.
- **Threshold check:** a sub-threshold upstream finding (`major`, single reviewer) must **not** abort
  the cycle — it is reported as an ordinary local finding.
- **Provenance:** AC-1 is `[agent]` → rollback proceeds autonomously; AC-2/AC-3 are `[user]` → blocking
  question, and a silent relaxation of either is a failed run.

### `plan.md` — negative control

Same profile, no `spec:` in frontmatter. `{UPSTREAM_DOCUMENT}` stays empty, so every finding must come
back `local` regardless of how upstream-ish it looks. An `upstream` finding here is a false positive:
it means a reviewer invented an address in a document that does not exist — the main escape hatch the
detector must not open.

## What this harness does NOT cover

- Pre/post structural equivalence against the pre-refactor `plan-review` — this would require a baseline captured before the rename/refactor landed (see PR #101), which was not done. Future refactors should capture baseline first; this harness provides the fixture set to do so.
- Multi-run modal match (3 runs per fixture) — stochasticity smoothing is out of scope for this lightweight harness.
- Fail-loud error cases (`UNKNOWN_PROFILE_HINT`, `FORBIDDEN_PROFILE_FIELD`, `NO_REVIEWERS_AVAILABLE`, `PROFILE_INVENTORY_MISMATCH`) — documented in `../profiles/README.md` but not executed here because they would require mutating the live profile set.
- Actual receipt writing for the `test-plan` profile — the captured baseline was produced via direct-agent invocation that bypasses the engine, so no receipt file is written during that capture. A real engine run on the same fixture (which has a `slug` in frontmatter and a profile with `receipt:` defined) will create or update `swarm-report/smoke-test-test-plan-fixture-test-plan.md`. Full receipt-payload validation must be exercised via a real `write-plan --test-plan → multiexpert-review` pipeline run.
- Test-plan receipt consumer flow (acceptance skill reading `review_verdict`) — out of scope.

## Captured baseline

See `baseline-results.md` in the same directory for a one-time capture of actual outputs against these fixtures. Newer runs can be compared against it for structural drift — keeping in mind PoLL stochasticity means exact content match is expected to fail; only structural invariants (profile detected, roster composition, verdict alphabet) are stable.
