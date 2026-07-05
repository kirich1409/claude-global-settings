Referenced from: `~/.claude/skills/finalize/SKILL.md` (§Phase C — PR review toolkit, §Phase D — Expert reviews).

# Finalize — Conditional Reviewer Matrix (Phase C + Phase D)

Per-agent tables and trigger conditions for the optional `pr-review-toolkit` quartet
(Phase C) and the conditional expert reviews (Phase D), including the `security-expert`
pattern triggers and the `test-coverage-expert` conditional. SKILL.md keeps the control
flow (invoke when available / when triggered, apply the shared fix-loop); this file holds
the matrices.

## Phase C — pr-review-toolkit quartet

| Agent | Focus | Fires |
|---|---|---|
| `pr-review-toolkit:pr-test-analyzer` | Test quality in diff — edge cases, behavioral vs implementation testing | always |
| `pr-review-toolkit:silent-failure-hunter` | Empty catch blocks, swallowed errors, overly broad catches, errors logged but not surfaced | always |
| `pr-review-toolkit:type-design-analyzer` | Can invalid states be represented? Invariants in types? Missing nullability, unsafe unions | always |
| `pr-review-toolkit:comment-analyzer` | Comment accuracy vs code, comment-rot, stale/misleading doc-comments | **only when the diff adds or modifies comments / doc-comments** — skip on pure-logic diffs to keep signal high |

The three `always` agents cover dimensions no other phase owns; `comment-analyzer` is gated on comment/doc changes because comment-rot is lower-priority and noisier than the other three — it earns its slot only when there are comments to audit.

## Phase D — expert review matrix

| Expert | Fires when |
|---|---|
| `architecture-expert` | new module, new public API surface, cross-module dependency change, or layered structure violation in diff |
| `security-expert` | spec/plan declared `risk_areas` ∈ {auth, payment, pii, data-migration}, or any pattern in the [Security-expert pattern triggers](#security-expert-pattern-triggers) table below |
| `performance-expert` | hot-path code (rendering, query loops, batch jobs), N+1 patterns, large-buffer allocations, threading/concurrency changes |
| `ux-expert` | UI-surface changes (composables, views, screens), copy / a11y / animation diffs |
| `build-engineer` | Gradle / Bazel / npm / Cargo / Xcode build script changes, plugin upgrades, version-catalog edits |
| `devops-expert` | CI / CD config, GitHub Actions / GitLab pipelines, deploy scripts, Dockerfile, infra-as-code |
| `business-analyst` | spec / requirements / scope changes (rare in finalize — usually fires upstream) |
| `test-coverage-expert` | see [`test-coverage-expert` (conditional)](#test-coverage-expert-conditional) below |

### `security-expert` pattern triggers

The default `risk_areas`-based trigger requires an explicit declaration in spec/plan; bug fixes and unspec'd tasks slip through. Phase D additionally fires `security-expert` on diff patterns:

| Category | Pattern (path or diff content) | Tier |
|---|---|---|
| Network layer | path under `/network/`, `/api/`, `/http/`, `/rpc/`, `/graphql/` | broad |
| Auth / Crypto | path under `/auth/`, `/crypto/`, `/token/`, `/session/` | narrow |
| Credential storage | diff mentions `SharedPreferences`, `EncryptedSharedPreferences`, `Keychain`, `UserDefaults`, `localStorage`, `sessionStorage`, `document.cookie`, `KeyStore` | narrow |
| Supply chain | new dependency line added in `build.gradle*`, `Podfile`, `Package.swift`, `package.json`, `pom.xml`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, `go.mod` | narrow |
| DB migrations | path under `migrations/`, `*.sql`, `Migration.kt`, `schema.prisma`, Flyway / Liquibase configs, `alembic/` | narrow |
| Deserialization | Jackson / Gson / `kotlinx.serialization` config blocks; unsafe Python-pickle usage, `XMLDecoder`, `ObjectInputStream` in diff | narrow |

**Threshold (false-positive control):**

- ≥ 1 narrow pattern → full security review (same as `risk_areas` trigger).
- ≥ 2 broad patterns → full security review.
- Exactly 1 broad pattern, no narrow → **scoped review**: launch `security-expert` with a narrowed prompt that names the specific surface (e.g. "audit the network layer for regressions only"), not a full audit. Reduces false-positive cost on incidental touches.
- No pattern + no `risk_areas` → security-expert does not fire. Other Phase D experts may still trigger.

**Override.** `--skip-security-review` (Tolerance flags) turns off both `risk_areas` and pattern triggers for the round. Recorded verbatim in `<slug>-finalize.md` `acknowledged risks` with user reason. Discouraged.

**Source.** Patterns evaluated against the unified diff between the remote default branch's merge-base and `HEAD` (same derivation as Phase A). Generate with rename detection (`git diff -M`). Path patterns match against the **new** path. Diff-content patterns match only added/modified hunks — a pure rename without content change cannot match content patterns but can match path patterns when the rename moves a file into a security-relevant directory.

### Handling expert findings

Same severity × confidence gate as Phase A. Specifics:

- Security-critical at confidence 50 — rely on `code-reviewer`'s **Critical-risk exception** (`~/.claude/agents/code-reviewer.md` § Critical-risk exception): finding is included with a `[please verify]` marker prefixed to `issue`. Treat as BLOCK; fix or escalate.
- Performance / architecture + critical ≥ 75: fix if local to the diff; escalate if broader rework needed.
- No parallel "always fix at 50" rule — the rubric is defined once in `code-reviewer.md` and inherited.

### `test-coverage-expert` (conditional)

Late-stage coverage audit complementing the early `/check` Phase 3.5 gate (#154). Catches declared TCs not implemented, data-layer changes without integration tests, and gaps the engineer agent missed. Public-API rule is defined in `~/.claude/rules/qa-and-testing.md` § 1; priority framework (P0–P3) in § 2.

**Trigger when ANY:** (1) diff adds a public API symbol with no matching test file (per § 1); (2) `docs/testplans/<slug>-test-plan.md` declares TCs without matching implementation in test sources for this slug — cross-reference by TC `Type` (#153) plus name / file mention, interpreted by the agent, not regex; (3) diff touches data-layer / repository / service / use-case files without introducing or updating tests; (4) `--coverage-audit`.

**Skip when ANY:** (1) trivial diff (single file, < 50 LOC, no new public API, refactor-only); (2) `--skip-coverage-audit` (recorded verbatim in finalize report); (3) no test infrastructure for the affected module — short-circuit with a follow-up issue ("add test harness for X"). Never silently skip.

Reuses existing engineer agents (`kotlin-engineer` / `swift-engineer` / `compose-developer` / `swiftui-developer`) with a coverage-audit prompt. The agent reads `docs/testplans/<slug>-test-plan.md`, the diff, and test files; writes `swarm-report/<slug>-coverage-audit.md`; on gaps, writes missing tests in the same Task call and re-runs `/check` (author-fixes-tests, qa-and-testing.md § 4).

**Schema for `swarm-report/<slug>-coverage-audit.md`:**

```markdown
# Coverage audit: <slug>

**Date:** <ISO date>
**Slug:** <slug>
**Triggered by:** new-public-api | tp-tc-mismatch | data-layer-no-tests | --coverage-audit
**Verdict:** PASS | GAPS_RESOLVED | ESCALATE

## Inputs
- Test plan: `docs/testplans/<slug>-test-plan.md` (or `N/A: no test plan`)
- Diff against: `origin/<base>` (commit hash range)
- Test files in diff: <list>

## Cross-reference

| TC ID | Type | Status | Test file |
|---|---|---|---|
| TC-1 | unit | covered | `src/test/.../FooSpec.kt` |
| TC-2 | ui-instrumentation | gap | — |

## Public API audit

| Symbol | File | Status | Test file |
|---|---|---|---|
| `LoginViewModel` | `feature/auth/.../LoginViewModel.kt` | covered | `LoginViewModelTest.kt` |
| `RateLimiter.allow()` | `core/.../RateLimiter.kt` | gap | — |

## Gaps and resolution
- (gap-1) TC-2 `Login error state` — added `LoginScreenInstrumentedTest`.
- (gap-2) `RateLimiter.allow()` — added `RateLimiterTest.allow_blocks_after_threshold`.

## /check after fixes
verdict: PASS
passed: [build, lint, typecheck, tests, coverage]
```

Verdict → Phase D outcome:

- `PASS` — all rows covered before audit; Phase D continues with other experts.
- `GAPS_RESOLVED` — agent wrote missing tests, `/check` PASS. Treated as PASS; audit file lists fixes for the finalize report.
- `ESCALATE` — agent could not produce a viable test in 3 attempts, OR a gap is structurally untestable. Treated as BLOCK; round budget applies.

`--skip-coverage-audit` is documented in §Inputs; when set, it records the skip reason in `acknowledged risks`.
