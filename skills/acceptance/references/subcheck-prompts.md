Referenced from: `~/.claude/skills/acceptance/SKILL.md` (§Step 3 mechanical block, §Step 4
judgement layers, §Step 5 device block).

# Acceptance — Per-Agent Sub-Check Prompts

Trigger conditions are **not** repeated here — they live once in
[`judgement-layers.md`](judgement-layers.md). This file holds what each agent is told and what
its verdict values mean.

## Spawn `manual-tester` (device block, L5)

`manual-tester` owns the runtime environment end-to-end per its Step 0. Acceptance does not
pre-launch — that is intentional delegation. Runs after L3 and L4, and only when they left no
BLOCK.

Prompt contents:
1. **Spec context** — full text or clear pointers.
2. **Test plan** — the complete set of test cases.
3. **Target hints** (optional) — device/URL if the user already named one.
4. **Scope** — which tiers (default: Smoke + Feature).
5. **Output path** — `swarm-report/<slug>-acceptance-manual.md` with the per-check schema.

If the agent returns `WARN` with `blocked_on`, surface that text to the user as the primary
next-step requirement before re-running acceptance.

## Spawn `code-reviewer` (always)

Prompt contents:
1. **Task description** — one sentence from spec or PR title.
2. **Plan pointer** — path to implement receipt or research report if present.
3. **Git diff** — current diff.
4. **Output path** — `swarm-report/<slug>-acceptance-code.md`.

Verdict rules: `PASS` if no semantic bugs, logic errors, or security issues; `WARN` for
style/minor; `FAIL` for blockers.

## Mechanical block — command selection

Used by §Step 3 when the project declares no explicit check target. Prefer the project's own
aggregate command (`./gradlew check`, `npm test`, `make check`) over the single-purpose
commands below; these are the fallback when only a build is resolvable.

| `ecosystem` | Command |
|---|---|
| `gradle` | `./gradlew build -x test --quiet` (single-module) or `./gradlew :check` (multi-module) |
| `node` | `npm run build` (or `pnpm build` / `yarn build`) |
| `rust` | `cargo build --release --quiet` |
| `go` | `go build ./...` |
| `python` | `python -m compileall .` or package-specific build |

Multi-module detection: scan `settings.gradle*` for `include(` statements. Subprojects declared
and no target named by the user → ask which module is the target **before** Step 3 starts.

Nothing resolvable → `verdict: SKIPPED` with `blocked_on: check commands unknown`, recorded as a
tracked exception, never as an inapplicable level. On failure capture the last ~50 lines only —
the exit code is the verdict, the log explains it. Receipt at
`swarm-report/<slug>-acceptance-mechanical.md` with `check: mechanical`.

## Spawn `business-analyst` (conditional — AC coverage)

Prompt contents:
1. **Spec** — the spec file path.
2. **Diff / implement receipt** — evidence for each AC.
3. **Test plan** (if any) — TC list mapped to AC via each test case's `Source:` field
   (e.g. `Source: AC-1` or `Source: AC-2, AC-3`). This is the canonical mapping defined in
   `write-plan/references/test-plan.md`; do not invent a new `AC-ref:` field.
4. **manual-tester output** (if running) — pointer to
   `swarm-report/<slug>-acceptance-manual.md`.
5. **Output path** — `swarm-report/<slug>-acceptance-ac-coverage.md`.

Verdict rules: `PASS` if every `AC-N` has at least one evidence pointer; `WARN` for weak
coverage (single witness on high-risk AC); `FAIL` for any missing AC. Severity: `FAIL` on
missing AC is `critical`; weak coverage is `major`.

## Spawn `ux-expert` (conditional — design-review or a11y)

Both modes require `has_ui_surface == true`: a11y on a backend, library, or CLI has no surface
to audit, so the trigger does not fire there even when `non_functional.a11y` is set.

Both modes firing → one invocation with mode `both`; the agent writes **two** artifacts so
aggregation treats them as independent checks:

- `swarm-report/<slug>-acceptance-design.md` with `check: design`
- `swarm-report/<slug>-acceptance-a11y.md` with `check: a11y`

When only one mode fires, only the corresponding artifact is written.

Prompt contents:
1. **Mode** — `design-review` / `a11y` / `both`.
2. **Spec** — file path.
3. **Design source** — `design.figma` URL (design-review mode).
4. **a11y target** — value of `non_functional.a11y` (e.g. `wcag-aa`).
5. **Running app pointer** — target hints; the agent reads running-app state via MCP only
   when the environment is already prepared, otherwise works from screenshots/code.
6. **Output paths** — one or both of the filenames listed above, matching the mode.

Verdict rules: `PASS` if design matches reference and a11y criteria met; `WARN` for minor
spacing/color deviations or AA soft failures; `FAIL` for missing components, broken
interaction paths, or hard a11y violations (keyboard trap, contrast below threshold).

## Spawn `security-expert` (conditional)

Prompt contents:
1. **Trigger** — the `risk_areas` subset, or the matched pattern categories and their tiers.
2. **Scope** — `full`, or `scoped` with the named surface when a single broad pattern matched.
   A scoped run audits that surface for regressions, not the whole codebase.
3. **Diff** — full git diff.
4. **Spec** — file path, when one exists.
5. **Output path** — `swarm-report/<slug>-acceptance-security.md`.

Verdict rules: `PASS` if no applicable OWASP / project-security-rule violations; `WARN` for
minor hardening opportunities; `FAIL` for exploitable issues, secret leaks, or regulation
breaches.

## Spawn `performance-expert` (conditional)

Prompt contents:
1. **SLA target** — from `non_functional.sla`; when the trigger came from the diff instead,
   say so explicitly and name the baseline used, since a verdict without a baseline number is
   not a performance result.
2. **Diff** — full git diff.
3. **Output path** — `swarm-report/<slug>-acceptance-performance.md`.

Verdict rules: `PASS` if no regression; `WARN` for borderline; `FAIL` for violations.

## Spawn `architecture-expert` (conditional — diff-triggered)

Prompt contents:
1. **Trigger reason** — `public-api` / `cross-module` / `new-module` / `layering` with the
   specific file list that matched.
2. **Diff** — full git diff (scoped to triggered files + their immediate neighbours).
3. **Module map** — list of top-level modules touched, discovered from
   `settings.gradle*` / `package.json` workspaces / `Cargo.toml` workspace members.
4. **Output path** — `swarm-report/<slug>-acceptance-architecture.md` with `check: architecture`.

Verdict rules: `PASS` if public contracts are preserved and module dependency direction is
clean; `WARN` for style issues (e.g., missing deprecation annotation, avoidable coupling);
`FAIL` for contract breakage, circular dependencies, or leaking internals into a public API.

## Spawn `build-engineer` (conditional — diff-triggered)

Prompt contents:
1. **Build files changed** — exact file list from the diff.
2. **Diff** — scoped to those files plus any touched module manifests.
3. **Ecosystem** — resolved `ecosystem` from Step 0 (drives which toolchain the agent should
   evaluate against).
4. **Output path** — `swarm-report/<slug>-acceptance-build-config.md` with
   `check: build-config`.

Note: the mechanical block already owns `check: mechanical`. Expert review of **config
changes** uses `build-config` so aggregation treats the two axes independently — a project can
build cleanly on a broken config, and vice versa.

Verdict rules: `PASS` if dependency additions are pinned/hash-verified, plugin versions are
consistent, and task wiring is intact; `WARN` for unpinned version ranges, unused
dependencies, or minor style issues; `FAIL` for breaking plugin mismatches, missing required
configuration, or dependency choices that conflict with project policy.

## Spawn `devops-expert` (conditional — diff-triggered)

Prompt contents:
1. **CI files changed** — exact file list.
2. **Diff** — scoped to CI/release files.
3. **Repo context** — `public` vs `private` (affects secret handling guidance),
   and any related marketplace/deployment manifests if present.
4. **Output path** — `swarm-report/<slug>-acceptance-devops.md` with `check: devops`.

Verdict rules: `PASS` if pipeline health is preserved, secrets are handled correctly, and
rollout gates remain sound; `WARN` for minor inefficiencies or missing
`timeout-minutes` / `concurrency` guards; `FAIL` for leaked secrets, disabled safety gates,
or breaking workflow syntax.

## Coverage audit (engineer agent, not a reviewer)

Executed by the engineer agent that owns the changed surface — `kotlin-engineer`,
`swift-engineer`, `compose-developer`, or `swiftui-developer`. It both audits and closes gaps,
which is why it is not a read-only reviewer.

Prompt contents:
1. **Trigger** — `new-public-api` / `tp-tc-mismatch` / `data-layer-no-tests` /
   `--coverage-audit`, with the symbols or TC IDs that matched.
2. **Test plan** — `docs/testplans/<slug>-test-plan.md`, or `N/A: no test plan`.
3. **Diff** — scoped to the changed sources plus their test sources.
4. **Mode** — `report` (default) or `fix`, passed through from `--fix`. In `fix` mode the
   mandate is to write the missing tests in this same call and re-run the project's
   mechanical-block commands; stopping after the audit is then an incomplete run. In `report`
   mode the mandate is the opposite: list the gaps and change nothing.
5. **Output path** — `swarm-report/<slug>-coverage-audit.md` (schema in
   [`judgement-layers.md`](judgement-layers.md) §Coverage audit), plus
   `swarm-report/<slug>-acceptance-coverage.md` with `check: coverage` carrying the verdict.

Verdict mapping: `PASS` → everything already covered; `GAPS_FOUND` → gaps listed in `report`
mode, treated as BLOCK; `GAPS_RESOLVED` → tests written and the mechanical block is green,
treated as PASS; `ESCALATE` → no viable test after 3 attempts or a structurally untestable gap,
treated as BLOCK.

## L3 / L4 automated device checks

Commands come from the project the same way the mechanical block's do — its instrumentation or
E2E task (`./gradlew connectedCheck`, `xcodebuild test -destination …`, the project's Playwright
or Maestro target). These run inside the device block, so they share its exclusive hold on the
device with `manual-tester` and never run concurrently with it.

Artifacts: `swarm-report/<slug>-acceptance-ui-tests.md` (`check: ui-tests`) and
`swarm-report/<slug>-acceptance-e2e.md` (`check: e2e`). No suite exists and none can be added
cheaply → `verdict: SKIPPED` with `blocked_on` naming what is missing. That is a tracked
exception, not an inapplicable level.
