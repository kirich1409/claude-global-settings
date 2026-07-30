Referenced from: `~/.claude/skills/write-plan/SKILL.md` (§Phase 2.5 — Optional test plan).

# Test plan — method and format

Analyze the feature from its specification, design, or implementation and produce a structured,
prioritized test plan as a markdown document. Nothing is executed here — the output is a document
for the `/acceptance` device block, the `manual-tester` agent, or a human QA engineer to pick up
later.

This ran as a standalone `generate-test-plan` skill until 2026-07-30. It is now a phase of
`write-plan`: the test plan is decided together with the implementation plan that it verifies,
not in a separate ceremony.

## Output

Save every test plan to the repository:

```
docs/testplans/<slug>-test-plan.md
```

Create the `docs/testplans/` directory if it doesn't exist. **The slug is the plan's slug**, the
same one that resolves `docs/plans/<slug>/` — never derive a second one. `/acceptance` mounts the
test plan by exact slug match, so a divergent slug silently breaks the hand-off.

### Receipt

Also emit a receipt at `swarm-report/<slug>-test-plan.md` so `multiexpert-review` and
`/acceptance` can mount the artifact via receipt-based gating. The permanent file under
`docs/testplans/` stays the source of truth; the receipt is metadata plus a pointer.

See [`test-plan-receipt.md`](test-plan-receipt.md) for the full YAML schema, the field conventions
(`status`, `review_verdict`, `review_warnings` / `review_blockers`, `phase_coverage`, `platform`,
`created` / `updated`), and how pre-existing files are mounted.

## Input Discovery

Sources may be a text spec (PRD / AC / user story), a Figma mockup, or existing code — often a combination. Cross-reference them; flag spec/code discrepancies as a finding, mark behaviour inferred from code alone with `[inferred from code]`.

**Spec frontmatter.** When the source is a file with YAML frontmatter and contains a `platform:` list, copy it verbatim into the receipt's `platform:` field (canonical values: `android | ios | web | desktop | backend-jvm | backend-node | cli | library | generic`, same as `write-spec`). Otherwise leave `platform:` empty in the receipt — `acceptance` falls back to its project-type heuristic.

**Figma mockup.** Use Figma MCP tools (`get_design_context`, `get_screenshot`) to extract screen states, interactive elements, navigation flows, and platform variants.

### Non-UI detector — when to use the lightweight template

Non-UI test plan trigger — see `~/.claude/rules/qa-and-testing.md` § 3. When the trigger fires, drop mockup-driven sections (Steps / Expected Result columns) and produce TCs whose behaviour is fully captured by Given/When/Then — focus on input validation, state transitions, and error paths. Mixed features (backend + thin UI) default to the standard format.

When the detector triggers, note it in the Findings section of the permanent file:
`**Lightweight template applied** — no UI surface detected; TCs use Given/When/Then only.`

## Test Plan Format

Every generated test plan has the same top-level layout: YAML frontmatter with `type: test-plan`
and `slug`, a header metadata table, then `Findings`, `Risk Areas`, `Test Cases`,
`Edge Cases & Negative Scenarios`, `Coverage Matrix`, and `Suggested Automation Candidates`.
Each `TC-[N]` block is itself a table with `Priority`, `Tier`, `Preconditions`, `Steps`,
`Expected Result`, and `Source` rows.

Two variants exist:

- **Standard format** — the default; full Steps + Expected Result columns.
- **Lightweight format (non-UI features)** — when the non-UI detector triggers, TC blocks
  collapse Steps and Expected Result into a single `Scenario (Given/When/Then)` row.
  All other sections are unchanged.

When the feature has two or more phases (e.g. a multi-stage rollout) and test cases can
be grouped by phase, split the `## Test Cases` section into `### Phase N (T-i..T-j) — <label>`
subsections (still one permanent file per feature). The receipt's `phase_coverage` then lists
the phase labels present.

See [`test-plan-templates.md`](test-plan-templates.md) for the full standard and lightweight templates (verbatim
markdown), the phase-segmentation worked example, and the rules for when each variant applies.

## Field Definitions

### Type

Every test case declares an explicit `Type` plus a one-line `Type rationale` (see `test-plan-templates.md`). Downstream consumers (the `/acceptance` coverage audit, `multiexpert-review` test-plan profile, engineer agents writing the actual tests) read this field — it is not optional.

| Type | Scope | Pick when |
|------|-------|-----------|
| `unit` | One class/function with mocked collaborators | Pure logic, transform, validator, mapper, parser, state-holder math |
| `integration` | Several classes plus real / in-memory dependencies | Repository + DB, service + test API, data pipeline, multi-class interaction |
| `ui-instrumentation` | One UI component inside its framework (Compose UI test, XCUITest single screen, ViewInspector) | Single screen / component user action with visible state assertion |
| `ui-scenario` | Running app driven by an MCP-based device / browser automation runner, re-runnable scripted journey | Multi-screen user journey, cross-platform critical flow |
| `screenshot` | Visual render comparison (Paparazzi, swift-snapshot-testing) | Visual fidelity is part of the contract — additive, never the sole coverage |
| `e2e` | Whole application end-to-end | Release-critical journey that cannot be split into smaller types — keep the count small |

#### Selection heuristic

Per acceptance criterion: pick the **smallest scope that catches a real failure of that AC**. Climb only when needed. When in doubt, prefer the cheaper type.

| AC shape | Type |
|---|---|
| Value transform / pure computation | `unit` |
| Component interaction with real or fake collaborators | `integration` |
| Single-screen user action with visible state change | `ui-instrumentation` |
| Multi-screen journey | `ui-scenario` |
| Release-critical journey + visual fidelity matters | `screenshot` (additive) and/or `e2e` |
| Release-critical end-to-end flow that cannot be split | `e2e` |

This heuristic is the canonical reference for picking a TC type within this plugin family.

### Priority

Priority framework — see `~/.claude/rules/qa-and-testing.md` § 2.

### Tier

| Tier | Meaning | Guideline |
|------|---------|-----------|
| **Smoke** | Is it alive? | Minimum set to confirm the feature works at all (3-5 tests max) |
| **Feature** | Does it work correctly? | Thorough coverage of the feature's behavior |
| **Regression** | Did we break anything? | Guards against breaking existing functionality |

### Source

| Source type | Format | Example |
|-------------|--------|---------|
| Spec section | `Spec §[section]` | `Spec §3.2 — Login flow` |
| Figma frame | `Figma: [frame name]` | `Figma: Login / Error State` |
| Code path | backtick-wrapped path with line | `src/auth/LoginViewModel.kt:87` |
| Inferred | `[inferred from code]` | Behavior derived from code with no spec backing |

### Non-functional / Instrumentation (mandatory for user-facing / prod-bound)

Every plan ends with a `## Non-functional / Instrumentation` section that declares observability **before** implementation, not after the first incident. Required when the spec / task is tagged `user-facing` or `prod-bound`, or when the feature touches an observability hot-path: network calls, payments, background jobs, auth, data migrations.

`N/A: <reason>` (one line) is allowed for internal / developer-only tooling and for pure refactors with no change to observable behavior. Never delete the heading.

The section covers five subsections — Log events / Metrics / Traces / Alerts / Dashboards (full template in [`test-plan-templates.md`](test-plan-templates.md#non-functional--instrumentation)). The skill reads naming and stack conventions (OpenTelemetry, Prometheus, StatsD, vendor-specific) from the project's `CLAUDE.md` and reuses them; it does not prescribe a stack. If the project has no convention, the skill asks one question and records the answer.

Downstream stages consume this section:

- `multiexpert-review` test-plan profile checks the section is filled or carries an explicit `N/A: <reason>`.
- `acceptance` verifies, against the running app, that declared events / metrics actually fire when the tested behavior runs.

## Guidelines

- Number test cases sequentially: TC-1, TC-2, TC-3 ... (manual-tester assigns session-scoped IDs at execution time).
- Each test case asserts exactly one thing — split multi-outcome verifications.
- Mark inferred behaviour with `[inferred from code]`.
- Target 15-30 test cases for a medium feature; every TC must earn its place.
