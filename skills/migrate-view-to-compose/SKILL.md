---
name: migrate-view-to-compose
description: Explicit-invocation workflow (not auto-triggered) for migrating a legacy Android View/XML screen to Jetpack Compose on the internal AlfaTheme / abm-uikit design system. Invoke manually via `/migrate-view-to-compose` or by calling this skill by name. Orchestrator — delegates screen code to `compose-developer`, Fragment wiring to `kotlin-engineer`, and post-migration review to `code-reviewer`; does not write code itself.
---

# Migrate View → Compose (AlfaTheme / abm-uikit)

Thin orchestrator skill. Plans the migration, delegates code to specialist agents, gates the result against a concrete quality checklist, leaves logic untouched.

## When not to use

- Writing a brand-new Compose screen (no legacy View to migrate) — use the feature-flow / implement path instead.
- Changing ViewModel / domain / navigation — that is scope creep, escalate.
- Navigation-infrastructure refactor — decision locked in `project_navigation_decision.md`.
- Screen is already Compose (partial migration) — verify with `ast-index outline <Fragment>` first; if `setContent { }` is present, this skill aborts.
- Pure Compose→Compose refactor (theme/token swap, componentisation) — use the feature-flow / refactor path.
- Cross-screen design-system migration spanning many screens at once — this skill is single-screen; run it repeatedly.

## Non-negotiables

Enforced on every migration — any violation blocks merge.

1. **Business logic is untouched.** `ViewModel`, `UseCase`, `Repository`, `Flow`, navigation routes, Koin modules — all stay as-is. Only the rendering layer changes. If logic restructuring seems required, stop and escalate.
2. **Two phases with a hard gate.** Migration runs as **Phase A — Discovery & Planning** (no code) then **Phase B — Implementation & Verification** (code). The user approves the Phase A plan before Phase B starts; see the *Workflow* section for the exit checklist. Writing code while mappings or gap decisions are open is how reflex "Material-instead", `Mode.Dark`-by-default, and sub-package misplacements slip in.
3. **AlfaTheme is the mandatory theme wrapper. Target theme defaults to Light.** Every migrated screen root is wrapped in `AlfaTheme { ... }`. The new UI Kit is light-first — the source `AlfaTheme` composable literally declares `mode: Mode = Mode.Light` with the comment *"always use Light mode by default"*. Migration from the old kit to the new one therefore **means moving to Light**; a legacy XML dark background (`NewAlfaTheme.Main` / `bg_1.webp` / `AlfaText.WhiteText.*`) is part of the OLD visual language and is expected to disappear on migration. **Dark is the exception, not the default**: use `AlfaTheme(mode = Mode.Dark)` only when the designer spec for this specific screen in the **new** UI Kit explicitly keeps it dark. When the XML baseline is dark or theme-forcing, run the Stage 1 **Theme decision checkpoint** — the skill asks the user and **recommends Light**; user answers `Dark` only with a design spec reference. Record the answer under `## Theme decision` in the plan. Do not enter Stage 3 without that record when the baseline is dark; the record is not required for baselines that are already light. All colours / typography / spacing come from `AlfaTheme.*` / `Gap.*` / `CornerSize.*` tokens — no hex, no inline `sp`, no magic `dp`. No Material / material3 components in migrated code — use `libs.abm.designsystem` (AlfaTheme) and `abm-uikit-ext` only. **`LegacyAlfaTheme` is forbidden** — it exists for lift-and-shift of the old visual style onto Compose; this skill's target is the new UI Kit, not the legacy look. See `references/uikit-mapping.md` and `references/ui-quality-checklist.md` §1.
4. **Missing UIKit component = hard pause.** Do not substitute Material. Do not inline a custom copy. Follow `references/missing-components-decision.md` — surface options to the user via `AskUserQuestion`.
5. **Do not delete old XML / Views.** Keep legacy `*.xml`, old Fragments, and `View` classes in place after migration — mark "pending deletion" in `PROGRESS.md` and wait for explicit user approval. Matches project rule `feedback_no_delete_old_code.md`.
6. **Never bypass git hooks; never commit to `develop`.** Work inside the `feature/compose-migration` branch / `.worktree/compose-migration` worktree (see `MEMORY.md` → *Compose Migration*).

## View whitelist — allowed after migration

A migrated screen may still contain these View-based elements. Anything else requires user approval via `AskUserQuestion`.

- `ComposeView` as the host inside the existing Fragment (wiring layer only).
- Navigation infrastructure Fragments — decision locked in `project_navigation_decision.md`.
- Widget-injection host Fragments — decision locked in `project_widget_injection_decision.md`.
- **`AndroidView { }` wrapping a complex third-party / native / functional-integration widget** — with these conditions:
  - **When permitted**: `WebView`, `MapView`, chat SDK views, camera / media surfaces (`SurfaceView` / `TextureView`), `RecyclerView` whose adapter logic cannot migrate without touching non-UI code, `ConstraintLayout` with Barrier/Chain logic that cannot be preserved in Compose `ConstraintLayout` without rewriting behaviour.
  - **Never permitted** for ordinary `TextView` / `Button` / `ImageView` / simple layouts — migrate those to Compose.
  - **Approval mechanics**: explicit screen-level user approval via `AskUserQuestion`, recorded in the plan under `## AndroidView exceptions` in the structured format from `missing-components-decision.md` Step 5. No informal approvals.
  - **Roborazzi**: skip the specific test function for the variant that renders `AndroidView` (not the whole file); add `// Roborazzi: AndroidView — not rendered in unit tests` to the skipped test.

Any other View (ordinary UI) outside this whitelist is a MUST violation.

**Fragment is preserved.** The migration does not replace the Fragment class or its lifecycle. The Fragment simply hosts a `ComposeView` that calls into a sibling Compose file next to it. `onCreateView` returns a `ComposeView` whose `setContent { AlfaTheme { <Screen>Content(...) } }` invokes the new composable. No navigation change, no DI change, no ViewModel re-wire.

## Pre-flight

Before delegating anything:

1. Confirm the current branch / worktree. If not on `feature/compose-migration` or a child branch off it, stop and confirm. Do not start on `develop`.
2. Confirm the target screen is actually View-based: `ast-index outline <Fragment>.kt` — if it already uses `setContent { }`, it is Compose; abort.
3. **Lock a scenario catalogue, then capture a device baseline per scenario.** A **state** is what a screenshot shows; a **scenario** is the reproducible user path that reaches that state. Stage 6 compares per scenario, not per state — fair comparison requires the same scenario on both sides.

   Write `swarm-report/<slug>-scenarios.md` following the format in `references/scenario-catalogue.md` (entry fields, minimum coverage, device config rules, naming). The catalogue is **frozen** the moment Stage 3 starts — no scenarios added, removed, or renamed mid-pipeline.

   For each scenario `S<n>`:
   - Execute the scenario deterministically on a running install of the **legacy XML** build.
   - Capture: `adb exec-out screencap -p > swarm-report/<slug>-baseline-S<n>.png` at the point named by `capture`.
   - Keep the device config fixed to the scenario's `device` line.

   Commit `scenarios.md` + all `baseline-S<n>.png` before Stage 3. A Roborazzi XML snapshot is nice to have for `compose-developer` reference but does not substitute the device baseline set.
4. **Module setup checks** — ensure dependencies that Stage 4 wiring and Stage 5 tests need are present in the target module:
   ```bash
   # Roborazzi (needed by Stage 3 screenshot test)
   grep -qE "abm[-.]testing[-.]roborazzi" <module>/build.gradle.kts && echo "OK" || echo "NEEDS: alias(libs.plugins.abm.testing.roborazzi)"
   # lifecycle-runtime-compose (needed by collectAsStateWithLifecycle() in Stage 4 patterns)
   grep -qE "lifecycle-runtime-compose|lifecycle.runtime.compose" <module>/build.gradle.kts && echo "OK" || echo "NEEDS: androidx.lifecycle:lifecycle-runtime-compose"
   ```
   If Roborazzi setup is missing, add the convention plugin and create the test `AndroidManifest.xml` (see Stage 5 for the manifest template). If `lifecycle-runtime-compose` is missing, add it via `implementation(libs.androidx.lifecycle.runtime.compose)` (catalog entry) or the project's preferred alias. Do this now so Stage 3/4 produce compilable code.
5. Read `docs/compose-migration/PROGRESS.md` on the migration branch — the target may already have notes or partial work.

## Workflow — two phases

The migration runs as two distinct phases separated by an explicit gate. **No code is written in Phase A.** No scenario, mapping, gap, or theme is decided during Phase B. Mixing the two blurs responsibility, hides unresolved questions, and lets reflex choices sneak in while the Composable is half-written.

**Phase A — Discovery & Planning (Stages 0-2)** — understand the screen, map every View, resolve every gap, lock the scenario catalogue, record the theme decision. Output: a complete plan the user can read end-to-end and approve.

**Phase A → Phase B gate (mandatory user approval)** — before any code is written, the orchestrator surfaces the full plan and asks the user to approve. The checklist below must hold; if even one item is missing, Phase B cannot start.

- `swarm-report/<slug>-plan.md` exists and covers: target Fragment path, full view-by-view mapping, state inputs preserved, `## Gap decisions` entry for every gap raised in Stage 1, `## AndroidView exceptions` entries in the structured format for any approved Option C, `## Theme decision` entry with target + rationale (if the Theme decision checkpoint was triggered).
- `swarm-report/<slug>-scenarios.md` exists and is frozen (per `references/scenario-catalogue.md` format) with complete device-config lines.
- `swarm-report/<slug>-baseline-S<n>.png` exists for every scenario `S<n>`.
- No Stage 1 flag or Stage 2 question left with status "open" / "TBD" / "verify later".

**Mechanical grep-gate** (orchestrator runs before presenting to user — all must pass):
```bash
PLAN="swarm-report/<slug>-plan.md"
grep -q "## Gap decisions"        "$PLAN" || echo "GATE FAIL: Gap decisions section missing"
grep -q "## Wiring pattern"       "$PLAN" || echo "GATE FAIL: Wiring pattern section missing"
grep -q "## Base class"           "$PLAN" || echo "GATE FAIL: Base class section missing"
grep -qiE "open|TBD|verify later" "$PLAN" && echo "GATE FAIL: unresolved open items in plan"
grep -q "## Theme decision"       "$PLAN" || echo "GATE WARN: Theme decision missing (required if XML baseline is dark)"
# Baseline PNGs
for S in $(grep "^## S" "swarm-report/<slug>-scenarios.md" | grep -o "S[0-9]*"); do
  ls "swarm-report/<slug>-baseline-${S}.png" 2>/dev/null || echo "GATE FAIL: baseline missing for ${S}"
done
```
Any `GATE FAIL` → do not proceed; fix the plan first.

If the user asks to change anything (add a scenario, revisit a gap decision, switch theme target) — handle it **in Phase A** and re-present. Phase A iterates; it does not proceed partial.

**Phase B — Implementation & Verification (Stages 3-8)** — write the Composable, wire the Fragment, run mechanical gates, diff per scenario on device, code review, close out. Once Phase B is running, the plan and scenario catalogue are frozen.

Progress is tracked with TaskCreate; each stage writes its artefact to `swarm-report/<slug>-stage-N.md`.

## Phase A — Discovery & Planning

### Stage 1 — Scope & mapping

Produce `swarm-report/<slug>-plan.md` with:

- Target Fragment / screen path and the XML layout(s) involved.
- **Complete component inventory** — every single View element in the XML must be listed in a table with its target Compose mapping. NOT just the "missing" ones. This is the input that decides whether Stage 2 needs to create new shared components, write inline composables, or reuse existing UIKit. The table is the audit trail.
- State inputs the screen consumes (ViewModel fields, Flows). Do not change them — just record them so the new Composable signature stays faithful.
- Screen states to preserve: Loading / Error / Empty / Content (see checklist §7).

#### Component inventory table — MANDATORY

Every View in the XML (custom widget, AppCompat, framework, Material) gets one row. Pick the lookup order:

1. **`references/legacy-view-mapping.md`** — for `by.st.alfa.ib2.ui_components.*` (pre-computed with confidence levels).
2. **`references/uikit-mapping.md`** — for standard framework / AppCompat / Material views.
3. **`ast-index search`** — confirm the candidate exists in `by.alfabank.uikit.components.*` or `core-ui-components/ui-components/.../components/`.

For each row, classify the **status** (this drives Stage 2):

| Status | Meaning | Stage-2 action |
|---|---|---|
| `existing-uikit` | Direct match in `abm.designsystem` (e.g. `Button`, `Switch`, `TextField`). | Use as-is. |
| `existing-shared` | Already in project's shared Compose module (`core-ui-components/ui-components/.../components/`, e.g. `AlfaDivider`, `PickerRow`, `BottomControlPanel`). | Use as-is. |
| `needs-shared` | No direct match, but the View is reused across **2+ screens** (current batch or known future migrations). | **Must create** in `core-ui-components/ui-components/.../components/` before Stage 3. |
| `inline-ok` | Truly screen-local with **only one call site**, ≤ 30 LOC, no theming complexity. | Allowed as a `private @Composable` in the screen file with a `// Local — single use, do not extract` comment. |
| `option-c` | Complex third-party widget needing `AndroidView`. | Apply Option C protocol (approval required). |
| `blocked` | Cannot map at all — feature itself unmigratable. | Escalate. |

Format the table:

```markdown
## Component inventory

| XML element | Lookup result | Status | Action |
|---|---|---|---|
| `Button @+id/sign_button` | UIKit `Button` | existing-uikit | use `by.alfabank.uikit.components.button.Button` |
| `View divider` | none | existing-shared | use `by.st.alfa.ib2.ui_components.components.AlfaDivider` |
| `TwoLineChooseView` | none | existing-shared | use `by.st.alfa.ib2.ui_components.components.PickerRow` |
| `BottomControlPanelView` | none, used in 8+ step screens | needs-shared | **create** `BottomControlPanel` in ui-components/commonMain |
| `WebView` | none, browser surface | option-c | `AndroidView` wrapper, approval ticket #... |
| `CustomBadge @+id/info_chip` | none, single screen | inline-ok | `private @Composable InfoChip()` in this file |
```

**Reuse audit — explicit count of call sites.** Before classifying as `inline-ok`, run a project-wide grep:

```bash
grep -rl "<by.fully.qualified.ViewClass\|<id_or_pattern>" --include="*.xml" --include="*.kt" | wc -l
```

If the count is **2 or more** (in the current branch — including non-migrated screens that will eventually need it), the status is `needs-shared`, not `inline-ok`. The reviewer at Stage 7 re-runs this grep and rejects `inline-ok` rows whose count exceeds 1.

**Batch inventory.** When migrating multiple screens in one batch (e.g. `cards/cards/cards-impl` step fragments), the inventory MUST be done across **all screens in the batch** before Stage 3 starts on the first screen. Components shared across the batch get classified as `needs-shared` once and built once. Doing one screen at a time and discovering the same component repeatedly is a process failure (see *Lesson — BottomControlPanel* in *Lessons learned* section).

The agent tasked with Stage 1 reads each XML in the batch, merges the component list, deduplicates by class name, and produces a **single** inventory table covering the whole batch. The `## Component inventory` section in the plan lives at the batch level (or the screen level if migrating one at a time), but the audit is always cross-batch when batches exist.

**Base class analysis** — `## Base class` section in the plan is **always mandatory**. For plain `Fragment()` or `BaseAlfaFragment()` write one line: `N/A — plain Fragment (Pattern A)` or `BaseAlfaFragment (Pattern B)`. For anything else, read the base class before proceeding and record:

1. **What lifecycle the base owns**: which of `onCreateView` / `onViewCreated` / `onActivityCreated` / `onDestroyView` does the base override? Does it set title, toolbar, navigation panel, action bar home icon?
2. **What abstract hooks the base expects**: e.g. `initView()`, `initViewModel()`, `onBack()`, `onNext()`, `onClose()` — these are called from the base lifecycle, not from the concrete Fragment directly.
3. **What shared infrastructure the base wires**: disposables (`CompositeDisposable`), navigation observers (`openPreviousScreen`, `openNextScreen`), stepper ViewModel observers, error handling.
4. **Does the base call `setContentView` or own `onCreateView`?** If yes — Pattern A (returning a ComposeView from `onCreateView`) may break the base; use Pattern B instead.

Recording this is mandatory before choosing the wiring pattern in Stage 4. Do NOT change the base class — any base class modification is scope creep and must be escalated.

**Wiring pattern selection rule** (feeds Stage 4):

| Base class structure | Recommended pattern |
|---|---|
| Plain `Fragment()` or base only uses `onDestroyView` | **Pattern A** — override `onCreateView` to return `ComposeView` |
| Base owns `onViewCreated`, has non-content children in XML (app-bar, toolbar) | **Pattern B** — keep XML, replace content area with `<ComposeView>`, wire in `onViewCreated` |
| Base calls abstract hooks (`initView()`, `onBack()`, `onNext()`, etc.) | **Pattern C** — create `ComposeView` inside the abstract content callback; other callbacks untouched |

Record the chosen pattern under `## Wiring pattern` in the plan with a one-line justification referencing the base class structure.

**Theme decision checkpoint** — if the XML baseline is rendered dark (uses `NewAlfaTheme.Main`, `NewAlfaTheme.DesignLight` (**despite "Light" in the name this theme renders a dark UI** — verify on device, not from the manifest name alone), `bg_1.webp`, dark backgrounds, white-on-dark text, or sets `android:theme` to a dark AppCompat style), or the screen forces a theme in any other way, ask the user via `AskUserQuestion` — **but with Light as the recommended default**, because migrating off the old kit means moving to Light unless a designer spec says otherwise:

> Screen `<slug>`: the legacy XML renders dark. New UI Kit is light-first, so Light is the expected target.
>
> **(A) Light — recommended.** The screen moves to `AlfaTheme.colors.bg.primary` / `text.primary` etc. Pick this unless you have a current design spec that explicitly keeps this screen dark in the new kit.
>
> Alternative — (B) **Dark**. Requires a design-spec reference in the rationale. The plan will wrap in `AlfaTheme(mode = Mode.Dark)` and may use `AlfaTheme.colors.static.*Light` tokens.

Record the chosen answer + rationale under `## Theme decision` in the plan. The reviewer at Stage 7 cross-checks `Mode.Dark` / `static.*` usages against this entry. If the XML baseline is already light (no forcing), skip the checkpoint — Light is the default and no record is needed.

### Stage 2 — Missing-components gate

For every flagged gap, follow `references/missing-components-decision.md` (options A composition / B UIKit request / C approved `AndroidView` for complex widgets only; never Material). Record resolutions in the plan under `## Gap decisions` and Option-C approvals under `## AndroidView exceptions` in the structured format the decision doc specifies. `AskUserQuestion` for every gap — do not proceed without a recorded answer.

#### Stage 2.5 — Component creation (NON-NEGOTIABLE)

For every row in the Stage 1 inventory marked `needs-shared`, the new component **must be created, compiled, and committed** before Stage 3 begins. Inline replacement at Stage 3 ("the agent will inline it for now") is **forbidden** — it produces the duplication problem (see *Lesson — Divider* in *Lessons learned*).

Steps for each `needs-shared` component:

1. Read the legacy View source (`ast-index class "<View>"`, then read the file). Note the public API: setters, callbacks, dynamic state, visual variants.
2. Read the legacy XML the View uses internally (`view_<name>.xml`). Note dimensions, gravity, default visibilities, color attrs.
3. Choose the location:
   - **Default — `core-ui-components/ui-components/src/commonMain/kotlin/by/st/alfa/ib2/ui_components/components/`** (KMP commonMain — usable from any Android dependent module). Use this for any component used in 2+ feature modules.
   - **Feature-impl `compose/` package** — only when the component is genuinely used by exactly one feature (e.g. `cards-impl` only). Even then, prefer ui-components if the component looks reusable.
4. Implement the Composable with the API matching the legacy setters (`showPrevious` ≈ `setPreviousVisibility`, `nextText` ≈ `setNextButtonText`, etc.). Use `AlfaTheme.*` tokens only.
5. Compile the host module: `./gradlew :core-ui-components:ui-components:compileDebugKotlinAndroid` (or the chosen module).
6. Commit the new component on `feature/compose-migration` with message `Add <ComponentName> shared Compose component`.
7. Update `## Gap decisions` in the plan: change `needs-shared → action: create <Component>` to `needs-shared → DONE: <package>.<ComponentName> committed in <sha>`.

**No screen migration starts until every `needs-shared` row is in `DONE` state.** This is the bright line.

**Why this is non-negotiable.** Skipping this and "inlining for now" creates 7 — 20 duplicates that must be cleaned up later (see *Lessons learned*). The cleanup costs more than upfront extraction, requires re-touching every migrated file, and risks introducing subtle behavior drift if the inline copies diverged.

**Exceptions** — only `inline-ok` rows skip Stage 2.5. Their definition (≤ 30 LOC, single call site, no theming complexity) is enforced by the Stage 7 reviewer.

#### Mechanical grep-gate for Stage 2 exit

Before declaring Phase A complete, run:

```bash
PLAN="swarm-report/<slug>-plan.md"
# Every needs-shared row must reference a committed sha
grep "needs-shared" "$PLAN" | grep -v "DONE:" && echo "GATE FAIL: needs-shared rows still pending creation"
# Every option-c row must have a structured AndroidView exception entry
grep "option-c" "$PLAN" | wc -l
grep -c "^- widget:" "$PLAN"   # counts must match
```

### Phase A → Phase B gate

Before launching Stage 3, run through the Phase A exit checklist (see the *Workflow* section above): plan complete, scenarios frozen with baseline PNGs, every `## Gap decisions` / `## AndroidView exceptions` / `## Theme decision` entry populated, zero "open" items, **every `needs-shared` component committed (Stage 2.5 DONE)**. Hand the plan to the user (`AskUserQuestion` — approve plan / revise <which section>) and wait for explicit approval. Partial approval is not a path forward; revisions loop back into Phase A.

**Mechanical exit check (orchestrator runs before presenting to user — all must pass):**

```bash
PLAN="swarm-report/<slug>-plan.md"
# Inventory present
grep -q "## Component inventory" "$PLAN" || echo "GATE FAIL: Component inventory section missing"
# No needs-shared rows still pending creation
grep "needs-shared" "$PLAN" | grep -v "DONE:" | grep -v "^|" && echo "GATE FAIL: needs-shared rows pending creation"
# Existing checks (theme, scenarios, gap decisions) — see Phase A exit
```

If even one `needs-shared` row is missing a `DONE: <sha>` marker, Phase B cannot start. Re-open Phase A, return to Stage 2.5, create the component, commit, update the plan, then re-run the exit check.

### Phase B → Phase A rollback

Once Phase B has started, the plan and scenario catalogue are frozen (MUST 10.8). A handful of situations **require** returning to Phase A rather than patching over them mid-flow. Each forces the orchestrator to re-open the plan, re-run the relevant gate, and re-approve via `AskUserQuestion` before resuming Phase B.

| Trigger | Required action | Actor |
|---|---|---|
| Late gap discovered during Stage 3 (widget not mapped, `AndroidView` Option C needs approval) | **compose-developer** pauses → **orchestrator** returns to Stage 2 missing-components gate → `AskUserQuestion` → record resolution → re-delegate to **compose-developer** with decision. | orchestrator triggers; compose-developer pauses/resumes |
| Scenario hole surfaces at Stage 6 (a state the catalogue missed) | **orchestrator** returns to Pre-flight → extends `scenarios.md` → captures new baseline on legacy XML build → re-runs Stage 6 for new entry only. | orchestrator |
| Theme-decision revision (designer spec changes, user revises Light/Dark answer) | **orchestrator** returns to Stage 1 checkpoint → updates `## Theme decision` → hands diff to **code-reviewer** to audit `Mode.Dark` / `static.*` usages → re-runs Stage 6. | orchestrator; code-reviewer for audit |
| Scope creep requested during Stage 3 or 4 | **orchestrator** stops immediately → escalates to **user**; user rejects (resume Phase B unchanged) or accepts as separate task. | orchestrator escalates to user |
| User approves `AndroidView` Option C mid-flow not in original plan | **orchestrator** returns to Stage 2 to record under `## AndroidView exceptions`; then **compose-developer** may use the wrapper. | orchestrator records; compose-developer resumes |

Every rollback writes one line to `## Phase rollbacks` in the plan: `YYYY-MM-DD | trigger | section updated | outcome`. Stage 7 reviewer reads this section to understand the plan's history and validates that the recorded resolution matches the code.

## Phase B — Implementation & Verification

### Stage 3 — Delegate implementation → `compose-developer`

Launch `compose-developer` agent. Prompt must include:

- Path to the plan and baseline screenshot.
- **Input contract** — the existing Fragment path (`<fragment-path>`). The new Composable **must** land as a sibling file in the same directory and same package as the Fragment. `compose-developer` is responsible for placement correctness before returning (not Stage 4).
- **Deliverables contract** — pair of absolute paths in the return:
  - `<composable-path>` = `<dirname(fragment-path)>/<Screen>Content.kt` (same package declaration as the Fragment).
  - `<preview-path>` = `<dirname(fragment-path)>/<Screen>Preview.kt`.
  - `<roborazzi-test-path>` = under `src/test/` (Android-only) or `src/androidUnitTest/` (KMP), per `MEMORY.md` Roborazzi section.
- Explicit instructions: use `AlfaTheme.*` tokens, `by.alfabank.uikit.*` components. **`AlfaTheme { }` wrapper lives at every render site EXCEPT the composable body itself: Fragment's `setContent { AlfaTheme { } }` (Stage 4), `@Preview` function bodies, and Roborazzi test's `captureRoboImage { AlfaTheme { } }` (Stage 5).** The composable itself must NOT wrap — it uses `AlfaTheme.colors.*` / `AlfaTheme.typography.*` tokens, which require a wrapper in its call site. Forbid `androidx.compose.material*`.
- **Composable is stateless and lives outside the ViewModel contract** (project wiring rule — not a generic Compose practice). Signature:
  ```kotlin
  @Composable
  internal fun <Screen>Content(
      state: <Screen>State,
      onAction: (<Screen>Action) -> Unit,
      modifier: Modifier = Modifier,
  ) { /* AlfaTheme tokens used here, but NO AlfaTheme { } wrapper */ }
  ```
  `collectAsStateWithLifecycle()` / `observeAsState()` lives **in the Fragment's `setContent { }`** (Stage 4). The Composable file has **zero** import of `ViewModel` / `LiveData` / `Flow` / project Koin.
- **Composable root: use `modifier` directly on the Column. NO `fillMaxSize()`, NO `Modifier.background(...)`.** The Fragment's `setContent` owns height expansion (`Box(fillMaxSize)`) and background (see Stage 4 patterns) — that is the Fragment's responsibility. `fillMaxWidth()` on the Column IS fine and expected. `AlfaTheme` does NOT set a background automatically. The composable just passes `modifier` to its root layout:
  ```kotlin
  @Composable
  internal fun <Screen>Content(..., modifier: Modifier = Modifier) {
      Column(modifier = modifier.fillMaxWidth().verticalScroll(...)) { ... }
  }
  ```
- CMP compatibility preference per `references/cmp-compatibility.md` — prefer CMP-friendly APIs where cheap; do not contort the code.

**Placement self-check** (agent substitutes real paths, runs before returning):

```
# 1. Parent directories must match:
dirname(<composable-path>) == dirname(<fragment-path>)   → PASS / FAIL: PLACEMENT VIOLATION

# 2. Package declarations must match:
first "package " line of <composable-path> == first "package " line of <fragment-path>  → PASS / FAIL: PACKAGE MISMATCH
```

If either check fails, the agent corrects placement before returning. The agent writes the composable, preview, and screenshot test. It does **not** touch the Fragment.

### Stage 4 — Delegate wiring → `kotlin-engineer`

Launch `kotlin-engineer` agent. Prompt must include:

- Existing Fragment path, ViewModel binding, the new Composable from Stage 3 (sibling file next to the Fragment).
- Reference implementations already wired: `deposits-impl`, `auth-impl`, `credit-impl` (per `MEMORY.md`).
- Requirement: **preserve the Fragment class** — keep lifecycle, ViewModel binding, navigation, arguments intact. **Read `## Base class` and `## Wiring pattern` from the plan before choosing a pattern.**
- **Wiring patterns — loaded from `references/wiring-patterns.md`.** Three patterns (A / B / C) with selection table, full Kotlin snippets, XML edits, edge cases. The plan's `## Wiring pattern` entry names the pattern; the agent reads only that section of the reference.

  Pattern summary:

  | Base class shape | Pattern |
  |---|---|
  | Plain `Fragment()` | A — `onCreateView` returns `ComposeView` |
  | `BaseAlfaFragment(R.layout.*)` with app-bar siblings | B — `<ComposeView>` in XML, wire in `onViewCreated` |
  | Base calls abstract hooks (`initView()`, etc.) | C — `ComposeView` inside the callback; base untouched |

  All three: `ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed`; Fragment owns `AlfaTheme { Box(fillMaxSize + background) }`; composable does not self-wrap.
- New composable file lives **next to the Fragment** in the same package (e.g. `<feature>/ui/<Screen>Fragment.kt` + `<Screen>Content.kt`). **Re-verify placement as a sanity check** — Stage 3 already enforced this, but run the same `dirname` / `package` diff once more; if mismatched (shouldn't happen with a correct Stage 3 deliverable), hand back to `compose-developer` instead of moving the file here (wiring is not the right place to fix placement).
- Forbid any logic change. If wiring surfaces logic problems, stop and escalate.

### Stage 5 — Run checks

All fast mechanical gates must pass **before any device run** (Stage 6). Failure here is cheaper than an install + manual walkthrough.

The **orchestrator** runs these commands at Stage 5; the Stage 7 `code-reviewer` does not re-run detekt / tests — it consults the Stage 5 output and focuses on checks detekt cannot see.

**Stage 5 artefacts — capture all gradle output to disk** so Stage 7 reviewer can read them (reviewer does not re-run gradle). Write each log to `swarm-report/<slug>-stage-5-<gate>.log`:

1. **detekt** — cheapest quality gate (includes Compose rules via `config/detekt/detekt-compose.yml`):

   ```bash
   ./gradlew :<module>:detekt > swarm-report/<slug>-stage-5-detekt.log 2>&1
   ```

2. **compile + lint**:

   ```bash
   ./gradlew :<module>:compileDebugKotlin > swarm-report/<slug>-stage-5-compile.log 2>&1
   ./gradlew :<module>:lintDebug           > swarm-report/<slug>-stage-5-lint.log    2>&1
   ```

3. **unit tests + Roborazzi (sanity)** — confirms the Composable compiles, renders without crash, and previews are valid. This is **not** the final visual gate; that happens at Stage 6 via device-screenshot diff.

   Full module setup (plugin, test manifest, test pattern, `@Config(sdk=[33])` rationale): `references/roborazzi-setup.md`. Loaded when Pre-flight step 4 reports `NEEDS SETUP`.

   ```bash
   ./gradlew :<module>:testDebugUnitTest                               > swarm-report/<slug>-stage-5-test.log 2>&1
   ./gradlew :<module>:testDebugUnitTest -Proborazzi.test.record=true  # first run / no prior snapshot
   ```

Any failure → loop back to the agent whose stage produced the failing file. **Do not install or launch the app on device/emulator until 1–3 are all green.**

**Cross-module check (bounded).** Run `compileDebugKotlin` on:
- (a) the migrated module (already done above)
- (b) `:apps:abm-android:common` — always; shared wiring layer, breakage blocks device install
- (c) **first-level direct** dependents returned by `ast-index dependents <module-name>` — skip transitive

If (c) returns more than 5 modules, ask the user which to cover — do not compile all of them by default. Testing transitive dependents is out of scope. A compile failure in a cross-module dependent bounces to `kotlin-engineer` only if caused by the Fragment/ComposeView wiring; unrelated failures escalate to the user.

### Stage 6 — Scenario-by-scenario device screenshot comparison (final approval gate)

Roborazzi in Stage 5 is **sanity** — it confirms the Composable renders. The **final approval signal** for the migration is a side-by-side device screenshot comparison of every scenario locked in Pre-flight `scenarios.md`, before and after. Skipping a scenario is not allowed.

**6a. Device smoke** — install and reach the migrated screen. Prefer the feature sample app when available (builds in seconds, isolates the screen) over the full main app:

```bash
# 1. Preferred — feature sample app, if the feature has one (colon-separated Gradle path):
./gradlew :<feature>:app:assembleDebug       # e.g. :deposits:app / :cards:app / :profile:app
./gradlew :<feature>:sample:assembleDebug    # e.g. :android-base-gradle-plugin:sample
# 2. Fallback — main debug app:
./gradlew :apps:abm-android:google:assembleDebug
```

For server-gated screens, use Demo Mode (same mechanism as Pre-flight baseline: authorization screen → top-right "Demo") to bypass real login.

**6b. Replay the scenario catalogue on the Compose build** — open `swarm-report/<slug>-scenarios.md` and execute every scenario exactly as written (same `entry`, same `setup`, same `steps`, same `device` config). No improvisation — if a scenario step cannot be reproduced on Compose (missing affordance, different navigation), that itself is a regression, **stop and return to Stage 3** rather than adapt the scenario.

For each scenario S1, S2, …:

```bash
adb exec-out screencap -p > swarm-report/<slug>-compose-S<n>.png
```

Missing a scenario from the catalogue set → loop back, do not proceed.

**6c. Compare & record verdict** — produce `swarm-report/<slug>-screenshot-diff.md`. Row shape: `Scenario | State | Baseline | Compose | Verdict | Notes`, one row per scenario.

**Load `references/ui-quality-checklist.md` before scoring rows.** Acceptance criteria and PASS/FAIL rules live in §10 (MUST 10.4–10.8) and §14 (universal visual criteria) of that file — the orchestrator reads them once and applies to every scenario row.

Any FAIL row → migration **not approved**. Hand back to `compose-developer` with the scenario ID, failing step number, diff note, and both PNGs. Attach `scenarios.md`, the diff document, and all `baseline-S<n>.png` / `compose-S<n>.png` pairs in the Stage 8 report.

### Stage 7 — Delegate review → `code-reviewer`

Launch `code-reviewer` with `references/ui-quality-checklist.md` as the authoritative rubric. Prompt must:

- Point the reviewer at the Composable files + screenshot tests.
- **Instruct the reviewer to read `references/ui-quality-checklist.md` §§1–12 and §14 first**, before running any grep-gates. Those sections are the authoritative rubric.
- Pass explicit paths to the **Stage 5 artefacts**: `swarm-report/<slug>-stage-5-detekt.log`, `-compile.log`, `-lint.log`, `-test.log`. The reviewer **reads** these; reviewer does NOT re-run gradle. If any artefact is missing, reviewer returns "not runnable — bounce to orchestrator".
- Mandate running the grep-gates in checklist §MUST (§§1–12, §14). These are lightweight text greps, not gradle runs.
- Return structured findings: `MUST` violations (blockers) and `SHOULD` findings (fix opportunistically).

Loop: on `MUST` violations, hand back to `compose-developer` (or `kotlin-engineer` for wiring issues) with the exact findings and re-run Stage 5 → 7 until clean.

### Stage 8 — Close out

- Update `docs/compose-migration/PROGRESS.md`: screen done, old XML "pending deletion", Fragment wiring status.
- Write `swarm-report/<slug>-<date>.md`: target, mapping table, checklist result, unresolved SHOULDs, next module.
- Do **not** delete old XML / View classes / old Fragment body. Surface the removable-file list and stop — wait for user approval.

## Escalation — return to user

Hand control back and wait when:

- Missing UIKit component cannot be resolved via options A, B, or an approved C (`AndroidView` for complex third-party widgets).
- `code-reviewer` reports a MUST violation that implementation agents cannot fix without scope change (logic tangled in UI, navigation coupling).
- Visual diff shows hierarchy-level difference implying a design decision, not a mapping miss.
- A View falls outside the whitelist and has no UIKit substitute (`AndroidView` is only valid for the approved complex-widget category).

One question per round, recommended option first.

## Lessons learned

Real cases from past migrations that drove the current process rules. **Read these before starting any new batch** — they exist because the rules above are the result of paying these costs once.

### Lesson — `BottomControlPanel` (Phase A inventory miss)

**What happened.** During cards card-issue migration (8+ step fragments), `BottomControlPanelView` was used as the bottom navigation panel in every step screen. No Compose equivalent existed in `abm.designsystem` or in any project module. The MEMORY.md note about `abm-uikit-ext.BottomControlPanel` referred to a phantom module that never existed.

Each `compose-developer` agent independently discovered the gap mid-Stage-3 and built an inline `BottomNavPanel` private composable inside its screen file. After 4 screens were committed, the inline implementations had drifted in subtle ways (different button colors, padding, border behavior). Cleanup required:

- Reading the legacy `BottomControlPanelView` to understand the canonical API (`setPreviousVisibility`, `setOnNextClickListener`, `setNextButtonText`, `isFinalStep` attr)
- Creating shared `BottomControlPanel` composable in `core-ui-components/ui-components/.../components/` (~120 LOC)
- Replacing inline implementations in 4 already-migrated screens
- Re-running compile + detekt + push

**Root cause.** Stage 1 inventory only listed "missing" components — it did not list every component used. Stage 2 was satisfied by the inline-implementation Option A without checking how many screens would need the same gap filled.

**Fixed by.** Stage 1 now requires a **complete component inventory** (every View → status row), with a cross-screen reuse audit (`grep -rl ... | wc -l`). Status `needs-shared` is mandatory when count ≥ 2. Stage 2.5 requires the component to be created and committed before Stage 3 starts.

### Lesson — `Divider` (inline duplication explosion)

**What happened.** Across 18 migrated screens, every `compose-developer` agent created its own private `Divider()` composable: a 5-line `Box(Modifier.fillMaxWidth().height(1.dp).background(AlfaTheme.colors.border.primary))`. Identical code copied 18 times.

The skill at the time said `// Local — single use` was acceptable for small composables. Each agent applied that rule individually without checking whether the composable would be needed elsewhere. The cleanup deleted ~1100 lines of duplicate code and added ~100 lines of shared component + 20 import statements.

**Root cause.** "Inline-OK" was applied per-screen without considering reuse. The reviewer at Stage 7 had no signal to flag the proliferation because each individual screen looked clean.

**Fixed by.** `inline-ok` now requires a hard check: project-wide grep count must be 1. If 2+, the row is `needs-shared`. The reviewer at Stage 7 re-runs the grep on Stage 1 inventory rows and rejects `inline-ok` rows whose count exceeds 1.

### Lesson — `PickerRow` / `PickerField` (naming drift across screens)

**What happened.** Seven screens implemented `private fun PickerRow(...)` with slightly different signatures (some had `error`, some had `enabled`, some had `showChevron`, some had `icon`). Four other screens implemented `private fun PickerField(...)` — same purpose, different name. Same root cause as `Divider`, plus a naming-discipline failure: each agent invented its own name without checking what other screens called it.

**Fixed by.** Stage 1 inventory now consults `references/uikit-mapping.md` and `references/legacy-view-mapping.md` for canonical Compose names. When a `needs-shared` component is created in Stage 2.5, it gets the canonical name (`PickerRow`, not `PickerField`); the mapping references are updated to record the new component so future migrations reuse the name.

### Process pattern (universal)

When a Stage 3 agent reports "I implemented this inline / created a small private composable for X", that is a Phase A failure, not a Stage 3 success. Stop, return to Phase A, do the proper inventory, create the shared component if reuse is plausible, then re-run Stage 3. The cost of this loop once is far less than the cost of 7-20 cleanups later.

## References

Ordered by workflow stage.

- **`references/scenario-catalogue.md`** — exact shape of `swarm-report/<slug>-scenarios.md` (entry format, coverage, device config, naming, freeze rule). Loaded during Pre-flight step 3.
- **`references/roborazzi-setup.md`** — convention plugin, test manifest template, `captureRoboImage` pattern, `@Config(sdk=[33])` rationale. Loaded when Pre-flight step 4 reports `NEEDS SETUP`.
- **`references/legacy-view-mapping.md`** — pre-computed table of project-specific legacy custom Views (`by.st.alfa.ib2.ui_components.*`) → UIKit / abm-uikit-ext replacements, with confidence levels. Loaded during Stage 1 (check first before running the Missing-components gate on a legacy custom view).
- **`references/uikit-mapping.md`** — View → AlfaTheme / abm-uikit lookup. Loaded during Stage 1.
- **`references/missing-components-decision.md`** — Protocol for Stage 2 gate.
- **`references/wiring-patterns.md`** — three Fragment wiring patterns (A/B/C) with full code, XML edits, edge cases. Loaded during Stage 4.
- **`references/ui-quality-checklist.md`** — MUST (grep-gates, blockers) + SHOULD criteria. Loaded during Stage 6c and Stage 7.
- **`references/cmp-compatibility.md`** — advisory: CMP-friendly APIs to prefer, Android-only APIs to avoid. Not a blocker. Loaded during Stage 3 when compose-developer decides between equivalents.
