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

## Non-negotiables

Enforced on every migration — any violation blocks merge.

1. **Business logic is untouched.** `ViewModel`, `UseCase`, `Repository`, `Flow`, navigation routes, Koin modules — all stay as-is. Only the rendering layer changes. If logic restructuring seems required, stop and escalate.
1a. **Two phases with a hard gate.** Migration runs as **Phase A — Discovery & Planning** (no code) then **Phase B — Implementation & Verification** (code). The user approves the Phase A plan before Phase B starts; see the *Workflow* section for the exit checklist. Writing code while mappings or gap decisions are open is how reflex "Material-instead", `Mode.Dark`-by-default, and sub-package misplacements slip in.
2. **AlfaTheme is the mandatory theme wrapper. Target theme defaults to Light.** Every migrated screen root is wrapped in `AlfaTheme { ... }`. The new UI Kit is light-first — the source `AlfaTheme` composable literally declares `mode: Mode = Mode.Light` with the comment *"always use Light mode by default"*. Migration from the old kit to the new one therefore **means moving to Light**; a legacy XML dark background (`NewAlfaTheme.Main` / `bg_1.webp` / `AlfaText.WhiteText.*`) is part of the OLD visual language and is expected to disappear on migration. **Dark is the exception, not the default**: use `AlfaTheme(mode = Mode.Dark)` only when the designer spec for this specific screen in the **new** UI Kit explicitly keeps it dark. When the XML baseline is dark or theme-forcing, run the Stage 1 **Theme decision checkpoint** — the skill asks the user and **recommends Light**; user answers `Dark` only with a design spec reference. Record the answer under `## Theme decision` in the plan. Do not enter Stage 3 without that record when the baseline is dark; the record is not required for baselines that are already light. All colours / typography / spacing come from `AlfaTheme.*` / `Gap.*` / `CornerSize.*` tokens — no hex, no inline `sp`, no magic `dp`. No Material / material3 components in migrated code — use `libs.abm.designsystem` (AlfaTheme) and `abm-uikit-ext` only. **`LegacyAlfaTheme` is forbidden** — it exists for lift-and-shift of the old visual style onto Compose; this skill's target is the new UI Kit, not the legacy look. See `references/uikit-mapping.md` and `references/ui-quality-checklist.md` §1.
3. **Missing UIKit component = hard pause.** Do not substitute Material. Do not inline a custom copy. Follow `references/missing-components-decision.md` — surface options to the user via `AskUserQuestion`.
4. **Do not delete old XML / Views.** Keep legacy `*.xml`, old Fragments, and `View` classes in place after migration — mark "pending deletion" in `PROGRESS.md` and wait for explicit user approval. Matches project rule `feedback_no_delete_old_code.md`.
5. **Never bypass git hooks; never commit to `develop`.** Work inside the `feature/compose-migration` branch / `.worktree/compose-migration` worktree (see `MEMORY.md` → *Compose Migration*).

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
4. Read `docs/compose-migration/PROGRESS.md` on the migration branch — the target may already have notes or partial work.

## Workflow — two phases

The migration runs as two distinct phases separated by an explicit gate. **No code is written in Phase A.** No scenario, mapping, gap, or theme is decided during Phase B. Mixing the two blurs responsibility, hides unresolved questions, and lets reflex choices sneak in while the Composable is half-written.

**Phase A — Discovery & Planning (Stages 0-2)** — understand the screen, map every View, resolve every gap, lock the scenario catalogue, record the theme decision. Output: a complete plan the user can read end-to-end and approve.

**Phase A → Phase B gate (mandatory user approval)** — before any code is written, the orchestrator surfaces the full plan and asks the user to approve. The checklist below must hold; if even one item is missing, Phase B cannot start.

- `swarm-report/<slug>-plan.md` exists and covers: target Fragment path, full view-by-view mapping, state inputs preserved, `## Gap decisions` entry for every gap raised in Stage 1, `## AndroidView exceptions` entries in the structured format for any approved Option C, `## Theme decision` entry with target + rationale (if the Theme decision checkpoint was triggered).
- `swarm-report/<slug>-scenarios.md` exists and is frozen (per `references/scenario-catalogue.md` format) with complete device-config lines.
- `swarm-report/<slug>-baseline-S<n>.png` exists for every scenario `S<n>`.
- No Stage 1 flag or Stage 2 question left with status "open" / "TBD" / "verify later".

If the user asks to change anything (add a scenario, revisit a gap decision, switch theme target) — handle it **in Phase A** and re-present. Phase A iterates; it does not proceed partial.

**Phase B — Implementation & Verification (Stages 3-8)** — write the Composable, wire the Fragment, run mechanical gates, diff per scenario on device, code review, close out. Once Phase B is running, the plan and scenario catalogue are frozen.

Progress is tracked with TaskCreate; each stage writes its artefact to `swarm-report/<slug>-stage-N.md`.

## Phase A — Discovery & Planning

### Stage 1 — Scope & mapping

Produce `swarm-report/<slug>-plan.md` with:

- Target Fragment / screen path and the XML layout(s) involved.
- View-by-View mapping. For any class under `by.st.alfa.ib2.ui_components.*` (project-specific legacy custom views), consult **`references/legacy-view-mapping.md` first** — it has the pre-computed replacements with confidence levels. For standard framework / AppCompat / Material views, use `references/uikit-mapping.md`. Flag every View with **no** direct match → input for the missing-components gate.
- State inputs the screen consumes (ViewModel fields, Flows). Do not change them — just record them so the new Composable signature stays faithful.
- Screen states to preserve: Loading / Error / Empty / Content (see checklist §7).

**Base class analysis** — if the target Fragment extends anything other than plain `Fragment()` or `BaseAlfaFragment()`, read the base class before proceeding and record under `## Base class` in the plan:

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

### Phase A → Phase B gate

Before launching Stage 3, run through the Phase A exit checklist (see the *Workflow* section above): plan complete, scenarios frozen with baseline PNGs, every `## Gap decisions` / `## AndroidView exceptions` / `## Theme decision` entry populated, zero "open" items. Hand the plan to the user (`AskUserQuestion` — approve plan / revise <which section>) and wait for explicit approval. Partial approval is not a path forward; revisions loop back into Phase A.

### Phase B → Phase A rollback

Once Phase B has started, the plan and scenario catalogue are frozen (MUST 10.8). A handful of situations **require** returning to Phase A rather than patching over them mid-flow. Each forces the orchestrator to re-open the plan, re-run the relevant gate, and re-approve via `AskUserQuestion` before resuming Phase B.

| Trigger | Required action |
|---|---|
| Late gap discovered during Stage 3 (widget not mapped, `AndroidView` Option C needs approval) | Stage 3 agent pauses → return to Stage 2 missing-components gate → `AskUserQuestion` → record resolution under `## Gap decisions` / `## AndroidView exceptions` → resume Stage 3 with the decision in hand. Already documented in `references/missing-components-decision.md` §Mid-Stage-3. |
| Scenario hole surfaces at Stage 6 (a state the catalogue missed — new Error condition, new Content variant, keyboard-open state) | Return to Pre-flight → extend `scenarios.md` with the missing entry → capture baseline for the new scenario on the **legacy XML build** (re-install if necessary) → re-run Stage 6 on the Compose build for the new entry only. Do **not** skip the new scenario or adapt existing ones. |
| Theme-decision revision (designer supplies new spec mid-flow, user changes their Light/Dark answer) | Return to Stage 1 Theme decision checkpoint → update `## Theme decision` entry with the new rationale → audit the Composable for `Mode.Dark` / `static.*` usages against the new answer (reuse §1.5 / §1.6 grep gates on a local run) → re-run Stage 6 scenario diff (visual delta is expected on the Compose side). |
| Scope creep requested during Stage 3 or 4 (new feature / logic change / new ViewModel field) | Stop immediately — this is a non-negotiable #1 violation. Escalate to the user with the requested change; user either rejects it (resume Phase B unchanged) or accepts it as a separate task (close this migration, open a new one). Do not silently absorb the change. |
| User approves an `AndroidView` Option C mid-flow that was not in the original plan | Same as the first row — return to Stage 2 briefly to record the approval under `## AndroidView exceptions` in the structured format; only then let the Composable use the wrapper. Stage 7 reviewer will grep-join the exception and fail if it is unrecorded. |

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
- Explicit instructions: use `AlfaTheme.*` tokens, `by.alfabank.uikit.*` components. **Do NOT wrap the composable body in `AlfaTheme { }`** — that wrapper lives in the Fragment's `setContent { AlfaTheme { } }` (Stage 4). The composable uses `AlfaTheme.colors.*` / `AlfaTheme.typography.*` for tokens only. Forbid `androidx.compose.material*`.
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
- **Root must fill the Fragment container.** Wrap the column/content in `Box(modifier = modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary))`. Without `fillMaxSize()`, a `ComposeView` placed in a `LinearLayout` with weighted siblings (e.g. `layout_weight=1`) will shrink to wrap-content height, and sibling views will dominate the screen. `AlfaTheme` does NOT set a background automatically — `background(AlfaTheme.colors.bg.primary)` must be explicit on the outermost Box.
  ```kotlin
  @Composable
  internal fun <Screen>Content(..., modifier: Modifier = Modifier) {
      Box(modifier = modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary)) {
          Column(modifier = Modifier.fillMaxWidth().verticalScroll(...)) { ... }
      }
  }
  ```
- CMP compatibility preference per `references/cmp-compatibility.md` — prefer CMP-friendly APIs where cheap; do not contort the code.

**Placement self-check** (agent runs before returning):

```bash
# Composable parent dir equals Fragment parent dir:
test "$(dirname <composable-path>)" = "$(dirname <fragment-path>)" || echo "PLACEMENT VIOLATION"
# Package declaration in composable file equals Fragment's package declaration:
diff <(grep -m1 "^package " <fragment-path>) <(grep -m1 "^package " <composable-path>) || echo "PACKAGE MISMATCH"
```

If either check fails, the agent corrects placement before returning. The agent writes the composable, preview, and screenshot test. It does **not** touch the Fragment.

### Stage 4 — Delegate wiring → `kotlin-engineer`

Launch `kotlin-engineer` agent. Prompt must include:

- Existing Fragment path, ViewModel binding, the new Composable from Stage 3 (sibling file next to the Fragment).
- Reference implementations already wired: `deposits-impl`, `auth-impl`, `credit-impl` (per `MEMORY.md`).
- Requirement: **preserve the Fragment class** — keep lifecycle, ViewModel binding, navigation, arguments intact. **Read `## Base class` and `## Wiring pattern` from the plan before choosing.** Three canonical wiring patterns (pick per plan):

  - **Pattern A — pure ComposeView host.** Fragment extends plain `Fragment()` (no base UI). `onCreateView` returns:
    ```kotlin
    ComposeView(requireContext()).apply {
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        setContent {
            AlfaTheme {
                Box(Modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary)) {
                    <Screen>Content(state, callbacks)
                }
            }
        }
    }
    ```
    Reference: `core-ui-components/sample/.../ComposeExampleFragment.kt`.

  - **Pattern B — keep XML shell, embed ComposeView.** Fragment extends `BaseAlfaFragment(R.layout.<legacy_xml>)`. The XML has a `<androidx.compose.ui.platform.ComposeView android:id="@+id/composeView"/>` replacing the old content area. Fragment calls `viewBinding.composeView.setContent { AlfaTheme { Box(...) { <Screen>Content(...) } } }` in `onViewCreated`, **after** all base lifecycle calls (`setTitle`, `setDisplayHomeAsUpEnabled`, etc.). Reference: `settings/app-settings/.../AllSettingsFragment.kt`, `auth/auth-impl/.../SetupGraphicalKeyFragment.kt`.

  - **Pattern C — inject into base callback.** Fragment extends a base that owns `onCreateView`/`onViewCreated` and calls abstract hooks (`initView()`, `onBack()`, `onNext()`, etc.). Same idea as Pattern A — create a `ComposeView` and call `setContent` — but the insertion point is the **abstract callback the base invokes**, not `onCreateView`. Base class stays completely untouched.
    ```kotlin
    // Base calls initView() from its own onViewCreated.
    // Concrete Fragment puts ComposeView setup here instead of View wiring.
    override fun initView() {
        ComposeView(requireContext()).also { composeView ->
            (view as? ViewGroup)?.addView(composeView)   // or binding.container.addView(...)
            composeView.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            composeView.setContent {
                AlfaTheme {
                    Box(Modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary)) {
                        <Screen>Content(state, callbacks)
                    }
                }
            }
        }
    }
    // initViewModel(), onBack(), onNext(), onClose() — left exactly as-is.
    ```
    If the XML already has a named container or a `<ComposeView>` id, use `binding.composeView.setContent { }` directly — no need to add a view programmatically.
    Reference pattern: any concrete `*StepFragment` subclass.

  All patterns use `ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed`. `onViewCreated` lifecycle calls (`setTitle`, `setDisplayHomeAsUpEnabled`, `observeStepperViewModel`, navigation observers) stay completely untouched.
- New composable file lives **next to the Fragment** in the same package (e.g. `<feature>/ui/<Screen>Fragment.kt` + `<Screen>Content.kt`). **Re-verify placement as a sanity check** — Stage 3 already enforced this, but run the same `dirname` / `package` diff once more; if mismatched (shouldn't happen with a correct Stage 3 deliverable), hand back to `compose-developer` instead of moving the file here (wiring is not the right place to fix placement).
- Forbid any logic change. If wiring surfaces logic problems, stop and escalate.

### Stage 5 — Run checks

All fast mechanical gates must pass **before any device run** (Stage 6). Failure here is cheaper than an install + manual walkthrough.

The **orchestrator** runs these commands at Stage 5; the Stage 7 `code-reviewer` does not re-run detekt / tests — it consults the Stage 5 output and focuses on checks detekt cannot see.

1. **detekt** — cheapest quality gate (includes Compose rules via `config/detekt/detekt-compose.yml`):

   ```bash
   ./gradlew :<module>:detekt
   ```

2. **compile + lint**:

   ```bash
   ./gradlew :<module>:compileDebugKotlin
   ./gradlew :<module>:lintDebug
   ```

3. **unit tests + Roborazzi (sanity)** — confirms the Composable compiles, renders without crash, and previews are valid. This is **not** the final visual gate; that happens at Stage 6 via device-screenshot diff.

   **Roborazzi module setup check** — before running tests, verify the module has Roborazzi configured. If not, set it up now (one-time per module):

   ```bash
   # Check: does the module already have Roborazzi?
   grep -q "roborazzi" <module>/build.gradle.kts && echo "already set up" || echo "NEEDS SETUP"
   ```

   If setup is needed:

   **`<module>/build.gradle.kts`** — one line, convention plugin handles everything:
   ```kotlin
   plugins {
       // existing plugins...
       alias(libs.plugins.abm-testing-roborazzi)
   }
   ```
   The `abm-testing-roborazzi` convention plugin applies `io.github.takahirom.roborazzi` and adds `testImplementation` for `roborazzi`, `roborazzi-compose` (NOT `roborazzi-compose-android` — absent from Nexus), and `robolectric`.

   **`src/test/AndroidManifest.xml`** (Android-only) or **`src/androidUnitTest/AndroidManifest.xml`** (KMP) — mandatory:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <manifest xmlns:android="http://schemas.android.com/apk/res/android"
       package="<app.package.id>">
       <application android:theme="@style/Theme.AppCompat">
           <activity android:name="androidx.activity.ComponentActivity"
               android:theme="@style/Theme.AppCompat" />
       </application>
   </manifest>
   ```
   `xmlns:android` is **required** — omitting it causes `prefix 'android' not bound` error. `package` is **required** for Robolectric activity resolution — without it Robolectric uses `org.robolectric.default` and cannot resolve `ComponentActivity`.

   **Test pattern** — use `captureRoboImage(filePath) { composable }`, NOT `createAndroidComposeRule<ComponentActivity>()`:
   ```kotlin
   @RunWith(RobolectricTestRunner::class)
   @GraphicsMode(GraphicsMode.Mode.NATIVE)
   @Config(sdk = [33], qualifiers = "w360dp-h800dp-xxhdpi")
   class <Screen>ScreenshotTest {
       @Test
       fun <screenName>() {
           captureRoboImage("screenshots/<Screen>Content.png") {
               AlfaTheme {
                   <Screen>Content(
                       // parameters
                   )
               }
           }
       }
   }
   ```
   `@Config(sdk = [33])` is required — higher SDK levels cause `NoSuchMethodError` in Compose text rendering with Robolectric. `createAndroidComposeRule<ComponentActivity>()` triggers activity-resolution failures in AGP 8+ even with a correct manifest; the direct `captureRoboImage { }` API avoids this. The test wraps the composable in `AlfaTheme { }` explicitly (the composable itself must not self-wrap).

   ```bash
   ./gradlew :<module>:testDebugUnitTest
   ./gradlew :<module>:testDebugUnitTest -Proborazzi.test.record=true   # first run / no prior snapshot
   ```

Any failure → loop back to the agent whose stage produced the failing file. **Do not install or launch the app on device/emulator until 1–3 are all green.**

Cross-module check: discover dependents via `ast-index dependents <module-name>` and run `compileDebugKotlin` + `testDebugUnitTest` for each. At a minimum check `:apps:abm-android:common` (shared wiring layer) — it consumes feature modules and breakage there blocks device install.

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

Acceptance criteria and PASS/FAIL rules live in `references/ui-quality-checklist.md` §10 (MUST 10.4–10.8) and §14 (universal visual criteria). Do not restate them here.

Any FAIL row → migration **not approved**. Hand back to `compose-developer` with the scenario ID, failing step number, diff note, and both PNGs. Attach `scenarios.md`, the diff document, and all `baseline-S<n>.png` / `compose-S<n>.png` pairs in the Stage 8 report.

### Stage 7 — Delegate review → `code-reviewer`

Launch `code-reviewer` with `references/ui-quality-checklist.md` as the authoritative rubric. Prompt must:

- Point the reviewer at the Composable files + screenshot tests.
- Pass paths to the **Stage 5 artefacts** (detekt report, compile/lint output, test run log) — the reviewer **reads** these; reviewer does NOT re-run gradle. Re-running is the orchestrator's responsibility; re-checks waste time and risk differing outputs. If a Stage 5 artefact is missing, reviewer returns "not runnable — bounce to orchestrator".
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

## References

- **`references/uikit-mapping.md`** — View → AlfaTheme / abm-uikit lookup. Loaded during Stage 1.
- **`references/ui-quality-checklist.md`** — MUST (grep-gates, blockers) + SHOULD criteria for Stage 7 reviewer.
- **`references/missing-components-decision.md`** — Protocol for Stage 2 gate.
- **`references/cmp-compatibility.md`** — CMP-friendly APIs to prefer, Android-only APIs to avoid. Guidance, not blocker.
- **`references/scenario-catalogue.md`** — exact shape of `swarm-report/<slug>-scenarios.md` (entry format, coverage, device config, naming, freeze rule). Loaded during Pre-flight step 3.
- **`references/legacy-view-mapping.md`** — pre-computed table of project-specific legacy custom Views (`by.st.alfa.ib2.ui_components.*`) → UIKit / abm-uikit-ext replacements, with confidence levels. Check this first at Stage 1 before running the Missing-components gate on a legacy custom view.
