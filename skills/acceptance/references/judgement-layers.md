Referenced from: `~/.claude/skills/acceptance/SKILL.md` (§Step 4 — Judgement Layers).

# Judgement layers (L1b) — routing, fix loop, budget

`code-reviewer` always runs. Every other reviewer is conditional and fires on **either** spec
frontmatter **or** a diff pattern. Both paths matter: frontmatter declares intent, but bug
fixes and unspec'd tasks carry no frontmatter at all, so a frontmatter-only gate silently
under-reviews exactly the changes least likely to have been designed.

## Reviewer matrix

| Reviewer | Fires on frontmatter | Fires on diff |
|---|---|---|
| `code-reviewer` | always | always |
| `business-analyst` | `acceptance_criteria_ids` non-empty | spec or requirements files changed |
| `ux-expert` (design) | `design.figma` set and `has_ui_surface` | UI-surface changes — screens, views, composables, copy, animation |
| `ux-expert` (a11y) | `non_functional.a11y` set and `has_ui_surface` | accessibility attributes or semantics touched |
| `security-expert` | `risk_areas` ∈ {auth, payment, pii, data-migration} | any pattern in §Security pattern triggers |
| `performance-expert` | `non_functional.sla` set, or `risk_areas` includes `perf-critical` | hot-path code (rendering, query loops, batch jobs), N+1 shapes, large-buffer allocation, threading or concurrency changes |
| `architecture-expert` | — | new module, new public API symbol, cross-module dependency change, layered-structure violation, or a diff spanning ≥ 3 top-level modules |
| `build-engineer` | — | `build.gradle*`, `settings.gradle*`, `pom.xml`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`, version-catalog edits, plugin upgrades |
| `devops-expert` | — | `.github/workflows/*`, `.gitlab-ci.yml`, `Dockerfile`, `docker-compose*`, `.circleci/config.yml`, deploy scripts, infra-as-code |
| coverage audit | — | see §Coverage audit |

Both `ux-expert` triggers firing → one invocation with mode `both`. No trigger fires → the
layer is `code-reviewer` alone, which is a valid outcome, not a misconfiguration.

**Public API heuristic** for `architecture-expert`:

- **Kotlin/Java** — `src/main/` changes adding, removing, or renaming `public` / `open`
  symbols, or touching `settings.gradle*`, `Module.kt`, `Dependencies.kt`.
- **TypeScript/JavaScript** — `export` / re-export lines, `index.ts` entrypoints,
  `package.json` `"exports"`.
- **Swift** — `public` / `open` declarations, `Package.swift` `products` / `targets`.
- **HTTP/RPC** — `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/api/**`, `*.proto`,
  `*.graphql`, `openapi.yaml`.
- **Cross-module** — changed paths span ≥ 3 top-level module directories per
  `settings.gradle*`, `package.json` workspaces, or `Cargo.toml` `[workspace]`.

Ambiguous → do **not** spawn `architecture-expert`. A false negative here is cheaper than a
false positive.

## Security pattern triggers

| Category | Pattern (path or diff content) | Tier |
|---|---|---|
| Network layer | path under `/network/`, `/api/`, `/http/`, `/rpc/`, `/graphql/` | broad |
| Auth / crypto | path under `/auth/`, `/crypto/`, `/token/`, `/session/` | narrow |
| Credential storage | diff mentions `SharedPreferences`, `EncryptedSharedPreferences`, `Keychain`, `UserDefaults`, `localStorage`, `sessionStorage`, `document.cookie`, `KeyStore` | narrow |
| Supply chain | a new dependency line in `build.gradle*`, `Podfile`, `Package.swift`, `package.json`, `pom.xml`, `Cargo.toml`, `requirements.txt`, `pyproject.toml`, `go.mod` | narrow |
| DB migrations | path under `migrations/`, `*.sql`, `Migration.kt`, `schema.prisma`, Flyway / Liquibase config, `alembic/` | narrow |
| Deserialization | Jackson / Gson / `kotlinx.serialization` config blocks, Python `pickle`, `XMLDecoder`, `ObjectInputStream` | narrow |

**Thresholds** — false-positive control:

- ≥ 1 narrow → full security review, same as the `risk_areas` trigger.
- ≥ 2 broad → full security review.
- exactly 1 broad and no narrow → **scoped review**: name the specific surface in the prompt
  ("audit the network layer for regressions only"), not a full audit.
- no pattern and no `risk_areas` → `security-expert` does not fire; other reviewers still may.

`--skip-security-review` disables both the frontmatter and the pattern trigger for the run, and
is recorded verbatim in the receipt's `acknowledged risks` with the user's reason. Discouraged.

## Coverage audit

Late-stage coverage check over what the mechanical block's public-API gate flagged plus what
the test plan declared. It exists because a green test run proves the written tests pass, not
that the right tests exist.

**Fires when any:** a public API symbol changed with no matching test (rule in
`~/.claude/rules/qa-and-testing.md` §Gate покрытия public API); `docs/testplans/<slug>-test-plan.md`
declares TCs with no matching implementation for this slug — cross-referenced by TC type and
name, interpreted by the agent, not by regex; the diff touches data-layer, repository, service,
or use-case files without adding or updating tests; `--coverage-audit`.

**Skips when any:** trivial diff (single file, < 50 LOC, no new public API, refactor only);
`--skip-coverage-audit`; the affected module has no test infrastructure — short-circuit and
file a follow-up ("add test harness for X"). Never skip silently.

**Executor: the project's engineer agent, not a dedicated reviewer** — `kotlin-engineer`,
`swift-engineer`, `compose-developer`, or `swiftui-developer`, invoked with a coverage-audit
prompt. It reads the test plan, the diff, and the test sources and writes
`swarm-report/<slug>-coverage-audit.md`.

Writing a test is a mutation, so it follows the same rule as every other fix: **under `--fix`**
the agent closes each gap in the same call and re-runs the mechanical block (the author fixes
their own tests — `~/.claude/rules/qa-and-testing.md`); **without `--fix`** it reports the gap
list and stops. A reported gap is still a BLOCK — an untested public symbol fails the gate
whether or not the gate was allowed to write the test.

```markdown
# Coverage audit: <slug>

**Date:** <ISO date>
**Triggered by:** new-public-api | tp-tc-mismatch | data-layer-no-tests | --coverage-audit
**Mode:** report | fix
**Verdict:** PASS | GAPS_FOUND | GAPS_RESOLVED | ESCALATE

## Inputs
- Test plan: `docs/testplans/<slug>-test-plan.md` (or `N/A: no test plan`)
- Diff against: `origin/<base>` (commit range)
- Test files in diff: <list>

## Cross-reference

| TC ID | Type | Status | Test file |
|---|---|---|---|

## Public API audit

| Symbol | File | Status | Test file |
|---|---|---|---|

## Gaps and resolution
- (gap-1) <what was missing> — <what was added>

## Mechanical block after fixes
verdict: PASS
ran: [build, lint, typecheck, tests]
```

`PASS` — everything already covered. `GAPS_FOUND` — gaps listed, nothing written (the default
mode); treated as BLOCK. `GAPS_RESOLVED` — tests written under `--fix` and the mechanical block
is green; treated as PASS. `ESCALATE` — no viable test after 3 attempts, or the gap is
structurally untestable; treated as BLOCK against the round budget.

## Grading and the fix loop

Findings are graded on the 0–100 confidence rubric defined once in
`~/.claude/agents/code-reviewer.md` and inherited by every reviewer. Violations of a
`## Non-negotiables` section in an applicable `CLAUDE.md` are BLOCK regardless of confidence
and are never moved to acknowledged risks.

| Severity × confidence | Grade | Action under `--fix` |
|---|---|---|
| critical ≥ 75 | BLOCK | Fix now, re-run the mechanical block. Green and resolved → BLOCK cleared. Doesn't converge → stays BLOCK, round ends without PASS. Never downgrade to "acknowledged risk". |
| major ≥ 75 | BLOCK | Fix if tractable. Needs refactoring beyond the diff → escalate; stays BLOCK until the caller resolves it or accepts it at ESCALATE. |
| minor ≥ 50 | WARN | Report only — not fixed even under `--fix`, never blocks. |

**Without `--fix` the loop does not exist.** Every grade is reported as-is, a surviving BLOCK
makes the run `FAILED`, and the receipt names what would have been fixed. This is the default:
the caller asked whether the change is acceptable, not for the gate to change it.

Fixes are delegated to the engineer agent that owns the surface — acceptance orchestrates and
judges, it never writes the fix itself.

**Under `--fix`, re-run the mechanical block after any mutation.** On failure:

1. Log which finding's fix broke it.
2. Narrow repair, **one attempt**. The code was green before this fix, so a regression means
   the fix was wrong; retrying compounds instead of converging.
3. Still red → revert the fix and keep the originating finding as BLOCK for the round. It
   counts against the budget and is never relabelled as an acknowledged risk.
4. Round ends with unresolved BLOCKs → next round. Budget exhausted (default 3, `--max-rounds`)
   → ESCALATE.

Never let mechanical failures cascade, and never use revert-and-continue to ship a BLOCK
quietly.

**ESCALATE — stop and hand back** when: BLOCKs survive the round budget; a mechanical failure
doesn't converge after its one retry; a BLOCK needs refactoring beyond the diff; an expert
finding demands an architectural change; the engineer agent required for a fix is not
installed. State which layer escalated, what is unresolved, and what the caller must decide.
