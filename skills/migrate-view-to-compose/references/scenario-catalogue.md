# Scenario catalogue format

Reference for Pre-flight step 3 of the migration workflow and for Stage 6 (final approval gate). The catalogue is the source of truth for the before/after screenshot comparison; freeze it before Stage 3 starts.

## File location

`swarm-report/<slug>-scenarios.md`

## Purpose

A **state** is what a screenshot shows (Loading, Error, Content variant). A **scenario** is the reproducible user path that reaches that state. Stage 6 compares baseline and Compose captures **per scenario** — fair comparison requires the same scenario ran on both sides. States alone are not enough; the operator must know exactly how to reach each state twice.

## Entry format

One numbered entry per scenario. Use this exact shape — Stage 7 reviewer grep-joins the IDs against captured PNGs.

```markdown
## S1 — <short descriptive name>

state: <Content | Content variant <name> | Loading | Error <condition> | Empty | Input-interaction <name>>
entry: <how to reach the screen from a cold start — Demo Mode path, deep-link, fragment graph, feature sample app launch>
setup:
  - <fixture 1: stubbed ViewModel value / Koin override / test server response>
  - <fixture 2>
steps:
  1. <user action or automatic wait>
  2. <...>
capture: <explicit moment — e.g. "after step 2, before the skeleton fades">
device: <model / API level / orientation / density / theme / font scale>
notes (optional): <anything non-obvious an operator needs>
```

Example:

```markdown
## S3 — Error: no network

state: Error, no-network
entry: Demo Mode → "Recovery" → step 1 of recovery flow
setup:
  - Emulator in airplane mode before launch
  - Default Demo Mode user (`pip`)
steps:
  1. Open the screen
  2. Wait for the initial request to time out
capture: after step 2, when the inline error text is visible
device: Pixel 4 / API 34 / portrait / xxhdpi / Light / font scale 1.0
```

## Minimum scenario coverage

Drop what the screen does not expose; extend when the screen adds more. The catalogue is exhaustive — Stage 6 treats missing scenarios as a regression. Coverage is checked mechanically against the **`## Coverage justification`** block below.

- **Content — default happy path** (S1 conventionally).
- **Content variants** — one scenario per state-machine branch:
  - role (admin / user / guest)
  - mode (editable / read-only)
  - data shape (single / list / empty-list / byn / fc)
  - auth state (logged-in / logged-out / expired session)
  - theme (Light / Dark — only if the screen supports both, per `## Theme decision`)
- **Loading** — reach the screen with data source deliberately slow and capture at the loading affordance.
- **Error** — one scenario per distinct error condition: no network, 4xx, 5xx, invalid input, blocked account, server timeout, rate limit, etc.
- **Empty** — if the screen has an empty state.
- **Input interactions** — validation error on a field, focused field, chip selection, keyboard open with content scrolled, submit-button disabled state.

## Coverage justification (mandatory)

After the scenario list, every `scenarios.md` file must include a `## Coverage justification` checklist. Each obligatory category is either checked (at least one `S<n>` covers it) or explicitly justified as `N/A` with a one-line reason. This block is grep-checkable from the Stage 7 reviewer.

```markdown
## Coverage justification

- [x] Content default — S1
- [x] Content variants — S2 (admin), S3 (read-only)
- [x] Loading — S4
- [x] Error — S5 (no network), S6 (invalid input)
- [ ] Empty — N/A because this screen always has at least one item
- [x] Input interactions — S7 (validation error), S8 (keyboard open)
```

Grep gates (run at Stage 7 against the plan / scenarios file):

```bash
SLUG=<slug>
FILE="swarm-report/${SLUG}-scenarios.md"
grep -E "^- \[[xX]\] Content default"      "$FILE" || echo "MUST 10.2: Content default not justified"
grep -E "^- \[[xX]\] Content variants"     "$FILE" || echo "MUST 10.2: Content variants not justified"
grep -E "^- \[([xX]| )\] Loading"          "$FILE" || echo "MUST 10.2: Loading not justified"
grep -E "^- \[([xX]| )\] Error"            "$FILE" || echo "MUST 10.2: Error not justified"
grep -E "^- \[([xX]| )\] Empty"            "$FILE" || echo "MUST 10.2: Empty not justified"
grep -E "^- \[([xX]| )\] Input interactions" "$FILE" || echo "MUST 10.2: Input interactions not justified"
```

Unchecked category MUST carry `— N/A because <reason>`. A category entirely missing from the block = MUST violation.

## Freeze rule

The catalogue is frozen the moment Stage 3 starts. No scenarios added, removed, or renamed mid-pipeline. Gaps discovered during Stage 6 escalate to the user (add-new-scenario request) — do not silently drop or rewrite existing scenarios to match a broken Compose build.

## Device config

Every scenario fixes its `device` line. Stage 6 replays the scenario on the Compose build with **the exact same** device config — Pixel model, API level, orientation, density, theme, font scale. Mismatched config invalidates the comparison.

A single screen normally uses one `device` value across all its scenarios; only vary when a scenario is specifically about a config (Light vs Dark, landscape, large font scale). In that case add a suffix to the ID (`S1-dark`, `S7-fontscale-1.3`) so captures do not collide.

## Capture naming

- `swarm-report/<slug>-baseline-S<n>.png` — legacy XML side, captured in Pre-flight.
- `swarm-report/<slug>-compose-S<n>.png` — Compose side, captured in Stage 6b.
- Suffix for config-varied scenarios matches the scenario ID suffix: `baseline-S1-dark.png`.

## Diff document

Stage 6c produces `swarm-report/<slug>-screenshot-diff.md`, one row per scenario ID with shape:

```
Scenario | State | Baseline | Compose | Verdict | Notes
```

Acceptance rules live in `ui-quality-checklist.md` §10 (MUST 10.4–10.8) and §14 (universal visual criteria).
