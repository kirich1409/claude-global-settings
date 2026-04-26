# UI quality checklist — post-migration

Authoritative rubric for Stage 7 (`code-reviewer`). Each item is either **MUST** (blocker) or **SHOULD** (tracked follow-up). Where possible, the item includes a grep-gate so the reviewer can run it mechanically.

Run grep-gates from the repo root, scoped to the migrated module:

```bash
MODULE=<path/to/module>   # e.g. features/auth/auth-impl
SCREEN_DIR=<path/to/new/compose>   # e.g. features/auth/auth-impl/src/main/kotlin/by/alfabank/auth/ui
```

## Legend

- ✅ correct / required
- ❌ forbidden / blocker when MUST
- **MUST** — fails review; send back to implementation agent.
- **SHOULD** — note in report; fix opportunistically; does not block.

---

## 1. Theme & imports (MUST)

Screen root is wrapped in `AlfaTheme { ... }`. No Material imports leak into the migrated files.

- **MUST 1.1** — No `androidx.compose.material.` / `androidx.compose.material3.` imports in migrated Composable files. The gate must be import-site (not substring) so `androidx.compose.material.ripple.*` can be explicitly exempted.
  ```bash
  grep -rnE "^\s*import\s+androidx\.compose\.material3?\." "$SCREEN_DIR" \
    | grep -vE ":\s*import\s+androidx\.compose\.material\.(ripple|icons)\."
  ```
  Any remaining hit is a MUST violation. Permitted subtrees:
  - `androidx.compose.material.ripple.*` — only when already used project-wide.
  - `androidx.compose.material.icons.*` — the vector-icon package. **But:** using `Icons.Default.*` / `Icons.Filled.*` / `Icons.Outlined.*` from this package is still forbidden — that is enforced separately by §5.4 (at the usage site, not the import). The import itself is allowed because some UIKit entry points re-use the container type; the rule in §5.4 bites if you actually reference the Material glyphs.

- **MUST 1.2** — No `MaterialTheme.` usages.
  ```bash
  ! grep -rn "MaterialTheme\." "$SCREEN_DIR"
  ```

- **MUST 1.3** — Root composable wraps content in `AlfaTheme { ... }` — or `AlfaTheme(mode = Mode.Dark)` when the plan's `## Theme decision` entry selects Dark (see §1.5). This is non-negotiable — the whole design system resolves through the `CompositionLocal` chain `AlfaTheme` establishes; an unwrapped composable renders with undefined tokens.
  ```bash
  grep -rn "AlfaTheme" "$SCREEN_DIR"   # must have ≥ 1 hit per screen file, including the top-level composable
  ```
  Reviewer verifies the wrap is at the screen root (not buried in a leaf composable).

- **MUST 1.4** — `LegacyAlfaTheme` is forbidden. It is a lift-and-shift bridge that reproduces the old visual style in Compose; this skill targets the new UI Kit, so any `LegacyAlfaTheme` usage defeats the migration purpose.
  ```bash
  grep -rnE "^\s*import\s+by\.st\.alfa\.ib2\.ui_components\.theme\.LegacyAlfaTheme\b" "$SCREEN_DIR"
  grep -rnE "\bLegacyAlfaTheme\." "$SCREEN_DIR"
  ```
  Any hit is a MUST violation. Replace `LegacyAlfaTheme.colors.legacy` / `LegacyAlfaTheme.typography` with `AlfaTheme.colors.*` / `AlfaTheme.typography.*` equivalents (see `uikit-mapping.md` §Tokens).

- **MUST 1.5** — **Default target theme is Light; `Mode.Dark` needs a `## Theme decision` entry with a design-spec reference.** New UI Kit is light-first — source `AlfaTheme(mode = Mode.Light)` default, with the literal comment "always use Light mode by default". A dark XML baseline (`NewAlfaTheme.Main` / `bg_1.webp` / white-on-dark text) is OLD-kit visual language and is expected to disappear on migration; it is **not** on its own a reason to pick Dark. When the XML baseline is dark, the plan must contain a `## Theme decision` entry written at Stage 1 via `AskUserQuestion` (Light recommended by default; Dark only when the user supplies a new-kit design-spec reference in the rationale).
  ```bash
  # catches both named-arg (mode = Mode.Dark) and positional (Mode.Dark) forms:
  grep -rnE "AlfaTheme\s*\(\s*(mode\s*=\s*)?Mode\.Dark" "$SCREEN_DIR"
  ```
  Any hit is cross-checked against the plan: listed under `## Theme decision` with target = Dark → acceptable; no such entry or entry marks Light → MUST violation.

- **MUST 1.6** — `AlfaTheme.colors.static.*` tokens (non-theme-adaptive light-on-dark pairs) are only valid for screens whose `## Theme decision` entry is Dark. For Light-target screens use theme-adaptive tokens (`AlfaTheme.colors.text.primary`, `bg.primary`, etc.).
  ```bash
  grep -rnE "AlfaTheme\.colors\.static\." "$SCREEN_DIR"
  ```
  Any hit is cross-checked against the same `## Theme decision` entry.

## 2. Typography (MUST / SHOULD)

Text styles come from `AlfaTheme.typography`. No inline `sp` numbers for size or letter-spacing.

- **MUST 2.1** — No inline `fontSize = ` with a number.
  ```bash
  ! grep -rnE "fontSize\s*=\s*[0-9]+\.?[0-9]*\.sp" "$SCREEN_DIR"
  ```

- **MUST 2.2** — No `TextStyle(fontSize = …)` constructed inline in screen code.
  ```bash
  ! grep -rn "TextStyle(" "$SCREEN_DIR" | grep "fontSize"
  ```

- **SHOULD 2.3** — Style choice matches role:
  - screen title → `headline.large` / `headline.medium`
  - section header → `headline.small` / `headline.xSmall`
  - body → `paragraph.primaryMedium` / `primaryLarge`
  - caption / muted → `paragraph.secondarySmall` / `tagline`
  - all-caps label → `paragraph.caps`

## 3. Colors & backgrounds (MUST)

Only tokens from `AlfaTheme.colors.*`.

- **MUST 3.1** — No raw hex colors.
  ```bash
  ! grep -rnE "Color\(0x[0-9A-Fa-f]{6,8}\)" "$SCREEN_DIR"
  ```

- **MUST 3.2** — No `Color.Black` / `Color.White` / `Color.Red` / other `Color.<Name>` constants.
  ```bash
  ! grep -rnE "(^|[^.])Color\.(Black|White|Red|Green|Blue|Yellow|Magenta|Cyan|Gray|LightGray|DarkGray)\b" "$SCREEN_DIR"
  ```

- **MUST 3.3** — Text color comes from `AlfaTheme.colors.text.*` or `static.text.*` (dark screens). Not from hex, not from `MaterialTheme`.

- **SHOULD 3.4** — Background matches role:
  - screen background → `bg.primary`
  - cards / grouped blocks → `bg.secondary` / `bg.tertiary`
  - divider lines → `border.primary` (1.dp `Box`)

## 4. Spacing (MUST / SHOULD)

Padding and arrangement come from `Gap.*` tokens or theme-level dimens.

- **MUST 4.1** — No `.padding(<n>.dp)` / `.size(<n>.dp)` / `.offset(<n>.dp)` / related Modifier extensions with magic literals ≥ 2 in screen code. Allowed: `Gap.*`, `CornerSize.*`, `dimensionResource(R.dimen.*)`, or `0.dp` / `1.dp` (borders only). All standard Modifier sizing/spacing helpers are covered — missing any would let magic `dp` leak through.
  ```bash
  # positional form — Modifier.{padding|size|width|height|defaultMinSize|requiredSize|requiredWidth|requiredHeight|widthIn|heightIn|sizeIn|offset}(<n>.dp…)
  grep -rnE "\.(padding|size|width|height|defaultMinSize|requiredSize|requiredWidth|requiredHeight|widthIn|heightIn|sizeIn|offset)\(\s*([2-9][0-9]*|1[0-9]+)\.?[0-9]*\s*\.dp" "$SCREEN_DIR"
  # named-arg form — start/top/end/bottom/horizontal/vertical/min/max/x/y
  grep -rnE "\.(padding|offset|widthIn|heightIn|sizeIn|defaultMinSize)\(\s*(start|top|end|bottom|horizontal|vertical|min|max|x|y)([A-Za-z]*)\s*=\s*([2-9][0-9]*|1[0-9]+)\.?[0-9]*\s*\.dp" "$SCREEN_DIR"
  ```
  Any hit is a MUST violation; replace with `Gap.*` or a theme dimension. `0.dp` and `1.dp` are not flagged by design.

- **SHOULD 4.2** — Screen margins from edges use `Gap.Medium` (16.dp) or `Gap.Large1X` (24.dp) per design spec. Between sections use `Gap.Large1X` / `Large2X` (24 / 32 dp). `Gap` token names are exact-case — the enum values are `None`, `Small3X`, `Small2X`, `Small1X`, `Small`, `Medium`, `Large`, `Large1X`, `Large2X`, `Large3X`, `Large4X`, `Large6X`, `Large7X`, `Large8X`. There is no `Gap.XSmall` / `Gap.XLarge`.

- **SHOULD 4.3** — Group consecutive same-size gaps via `Arrangement.spacedBy(Gap.X)` on the parent `Column` / `Row` rather than per-child padding.

## 5. Components (MUST)

Interactive and structural components come from UIKit.

- **MUST 5.1** — Buttons use `by.alfabank.uikit.components.button.Button`. No Material buttons via import.
  ```bash
  grep -rnE "^\s*import\s+androidx\.compose\.material3?\.(Button|OutlinedButton|TextButton|FilledTonalButton|ElevatedButton|IconButton|FilledIconButton|FloatingActionButton|ExtendedFloatingActionButton)\b" "$SCREEN_DIR"
  ```
  Any hit is a MUST violation.

- **MUST 5.2** — `Checkbox` / `Switch` / `RadioButton` / `Chip` / `SegmentedControl` come from `by.alfabank.uikit.components.*`. No hand-rolled Box + Icon imitation, no Material imports.
  ```bash
  grep -rnE "^\s*import\s+androidx\.compose\.material3?\.(Checkbox|Switch|RadioButton|Chip|FilterChip|AssistChip|InputChip|SuggestionChip)\b" "$SCREEN_DIR"
  ```

- **MUST 5.3** — Top bar is `by.alfabank.uikit.components.navigation.NavigationBar` inside `by.alfabank.uikit.components.Scaffold`. No Material `TopAppBar` / Material `Scaffold`.
  ```bash
  grep -rnE "^\s*import\s+androidx\.compose\.material3?\.(Scaffold|TopAppBar|CenterAlignedTopAppBar|MediumTopAppBar|LargeTopAppBar|BottomAppBar)\b" "$SCREEN_DIR"
  ```

- **MUST 5.4** — Icons come from `by.alfabank.uikit.Icons.Glyph.*` or project drawables. No `Icons.Default` / `Icons.Filled` / `Icons.Outlined`.
  ```bash
  ! grep -rnE "Icons\.(Default|Filled|Outlined|Rounded|Sharp|TwoTone)\." "$SCREEN_DIR"
  ```

- **MUST 5.5** — Dividers are a 1.dp `Box` with `AlfaTheme.colors.border.primary`. No Material `Divider` / `HorizontalDivider` / `VerticalDivider`.
  ```bash
  grep -rnE "^\s*import\s+androidx\.compose\.material3?\.(Divider|HorizontalDivider|VerticalDivider)\b" "$SCREEN_DIR"
  ```

## 6. Screen states (MUST)

Migrated screen must render every state that the original renders. Missing states silently regress UX.

- **MUST 6.1** — Each screen state from the original XML (Loading / Error / Empty / Content) has a corresponding branch in the Composable.
- **MUST 6.2** — Loading uses `Skeleton` / `TextSkeleton` — not a Material spinner. Indeterminate spinners only when the original was also a spinner and skeleton is inapplicable.
- **MUST 6.3** — Error uses `CompactError` (inline) or `FullscreenError` (whole-screen failure).
- **SHOULD 6.4** — Empty state uses `Plate` (info banner) or a dedicated illustrated-empty component when present.

## 7. Accessibility (MUST / SHOULD)

- **MUST 7.1** — Every `IconButton` / icon-only clickable element has `contentDescription` (not `null`, not `""`).
  ```bash
  grep -rnE "contentDescription\s*=\s*null" "$SCREEN_DIR"
  ```

- **SHOULD 7.2** — Custom clickable rows apply `Modifier.semantics { role = Role.Button }` (or matching Role) — standard Compose a11y; left as SHOULD because compose-developer will do this by default.

- **SHOULD 7.3** — Interactive touch targets ≥ 48.dp in code (`Modifier.minimumInteractiveComponentSize()` / explicit `size`). §14.4 is the visual equivalent.

- **SHOULD 7.4** — Key elements expose `testTag` for screenshot / UI tests (project-specific — used by Roborazzi selectors).

## 8. Hosting — Fragment + ComposeView (MUST)

- **MUST 8.1** — Fragment class is **preserved**. No Fragment rename, no navigation change, no argument-shape change. `onCreateView` returns a `ComposeView` whose `setContent { AlfaTheme { <Screen>Content(...) } }` calls the sibling composable file. No XML inflation remains in `onCreateView` beyond the `ComposeView` root.
- **MUST 8.2** — New composable file lives **in the same package, next to the Fragment** (e.g. `<feature>/ui/<Screen>Fragment.kt` + `<Screen>Content.kt`). Not in a `local/`, `new/`, `compose/` sub-package invented for the migration.
- **MUST 8.3** — `ViewModel` / Koin scopes / collectors remain byte-identical — `git diff` shows only the `onCreateView` body change plus the new composable file. Logic changes = scope violation.
- **MUST 8.4** — Composable screen contains no `ComposeView` (nested hosting). `AndroidView { }` is allowed **only** for approved complex third-party / native widgets and **only** when listed in the plan under `## AndroidView exceptions` in the structured format from `missing-components-decision.md` Step 5.

  Mechanical cross-check (all three greps; output joined by `file:widget` key):

  ```bash
  SLUG=<slug>
  # 1. Every AndroidView call site (file:line):
  grep -rnE "\bAndroidView\s*[\({]" "$SCREEN_DIR"

  # 2. Widget class extracted from each AndroidView — the factory MUST be single-line
  #    so this grep can resolve `factory = { ctx -> <Widget>(ctx) }` directly.
  grep -rnE "factory\s*=\s*\{[^}]*\b([A-Z][A-Za-z0-9]+)\s*\(" "$SCREEN_DIR"

  # 3. Approved exceptions in the plan (whitespace-tolerant around pipes):
  grep -E "^-\s*widget:\s*.+\s*\|\s*file:\s*.+\s*\|\s*reason:\s*.+\s*\|\s*cited-symbols:\s*.+\s*\|\s*approved:\s*[0-9]{4}-[0-9]{2}-[0-9]{2}" "swarm-report/${SLUG}-plan.md"
  ```

  **Strict join rule.** For every grep-hit at `<file>:<line>`:
  1. Extract `<Widget>` from grep 2 (same file). If the factory is multi-line so the widget cannot be extracted in one grep line → the implementer must either make the factory single-line OR extract the widget constructor into a named helper (`private fun buildWebView(ctx: Context): WebView`) and use it as `factory = ::buildWebView`. The single-line requirement is a grep-tool limitation, not a style demand — both paths satisfy it.
  2. Look for a plan entry where `file ==` the source file and `widget ==` the extracted class **by exact string match**. No fuzzy matching, no class-hierarchy assumptions.
  3. Decide:
     - Exact match found → SHOULD (verify wrapper correctness, Roborazzi skip annotation, cited-symbols really exist in the adapter).
     - No exact match, or widget missing from plan → **MUST violation** (unauthorised `AndroidView`; must migrate or request approval).
     - `<Widget>` is ordinary UI (`TextView` / `Button` / `ImageView` / `LinearLayout` / `ScrollView` / `EditText` / `FrameLayout` / `RelativeLayout` / `ConstraintLayout` with trivial use) regardless of approval → **MUST violation** (ordinary UI never qualifies for Option C).

- **MUST 8.5** — **Edge-to-edge: outer Box carries `windowInsetsPadding(WindowInsets.navigationBars)`.**
  Fragment's `setContent` must wrap the composable call in a `Box` that carries `.windowInsetsPadding(WindowInsets.navigationBars)`. This ensures the Compose tree consumes the navigation-bar inset before it reaches any child — preventing content from being clipped by the system navigation bar. Root cause: the Activity's `fitsSystemWindows` propagation does not reach an embedded `ComposeView`; `windowInsetsPadding` is the explicit fix.
  ```bash
  grep -rn "windowInsetsPadding" "$SCREEN_DIR"/../*Fragment.kt  # must hit the Fragment wiring file
  grep -rn "navigationBars" "$SCREEN_DIR"/../*Fragment.kt        # must appear alongside it
  ```
  Any Fragment wiring file that lacks both → MUST violation.

- **MUST 8.6** — **Edge-to-edge: `Scaffold` uses explicit `contentWindowInsets = WindowInsets.systemBars`.**
  Any `Scaffold(...)` call in the Content file must pass `contentWindowInsets = WindowInsets.systemBars`. This makes Scaffold apply the correct inset-based padding to its content slot (status bar top + navigation bar bottom), complementing §8.5 which handles the outer container.
  ```bash
  grep -rn "Scaffold(" "$SCREEN_DIR" | grep -v "contentWindowInsets"
  ```
  Any hit (a `Scaffold` call that omits `contentWindowInsets`) is a MUST violation — either add the argument or confirm the screen has no Scaffold (which is then fine).

## 9. Previews & Roborazzi snapshots (MUST / SHOULD)

Roborazzi is the **Compose-function sanity gate** — it confirms the Composable compiles, renders without crash, applies design tokens, and covers all screen states. It is **not** the final visual-parity gate (that is Stage 6 / §10). The criteria below define what a Roborazzi snapshot must look like to pass sanity; pixel-parity with the XML baseline is explicitly **not** required here.

### Existence

- **MUST 9.1** — A `@Preview` function exists for the screen, wrapped in **`AlfaTheme { }`** (project rule — Material `MaterialTheme` wrapping in a preview is still forbidden). Generic detekt rules (`PreviewPublic` / `PreviewAnnotationNaming`) are enforced at Stage 5 via `./gradlew :<module>:detekt`; the implementer knows those conventions, so this checklist does not re-state them.
- **MUST 9.2** — Roborazzi screenshot test exists under `src/test/` (Android-only modules) or `src/androidUnitTest/` (KMP modules). Uses `roborazzi-compose` dep (not `roborazzi-compose-android`, which is absent from Nexus).
- **MUST 9.3** — One Roborazzi snapshot per enumerated screen state from Pre-flight (Loading / each distinct Error / Empty / Content default / each Content variant). Same enumeration as §10.1 — coverage drift between Roborazzi and §10 enumeration is a regression.
- **MUST 9.4** — AndroidManifest present at the right path (Android-only → `src/test/AndroidManifest.xml`; KMP → `src/androidUnitTest/AndroidManifest.xml`) with `xmlns:android` declared.
- **SHOULD 9.5** — Preview / snapshot variants cover Light + Dark (unless the screen is dark-forced). Extra preview axes (font scale, RTL, long-text) are standard Compose practice — leave to the implementer.

### Snapshot acceptance criteria — what a passing PNG must show

A Roborazzi snapshot fails sanity if any of these are violated.

- **MUST 9.6** — **Test passed** — no crash / exception / timeout during composition. Reviewer checks the test report, not just the PNG.
- **MUST 9.7** — **Snapshot is non-empty** — the captured PNG is not blank, transparent, or solid-background-only. The expected screen content is visible. Heuristic: file size > 5 KB and a visual check shows non-trivial composition.
- **MUST 9.8** — **State matches its label** — the `Loading` snapshot shows a loading affordance (skeleton / progress), the `Error` snapshot shows the error UI with its message, the `Empty` snapshot shows the empty-state composable, etc. A snapshot whose contents do not match its filename / test name is broken state plumbing → MUST.
- **MUST 9.9** — **Theme applied** — visible colors / typography come from `AlfaTheme` tokens, not Material defaults. Concrete reds:
  - No Material purple / teal accents.
  - No `Color.Black` text on `Color.White` background unless that is the resolved AlfaTheme combination.
  - No "missing string resource" placeholders (`!string/foo`) or "missing icon" boxes.
  - The screen root composes through `AlfaTheme { ... }` (verified at code level by §1.3; visually here).
- **MUST 9.10** — **Visual content quality** — every PNG passes the universal criteria in §14 (readability, contrast, layout, element integrity, state clarity). Reviewer applies §14 to both Roborazzi snapshots (§9) and device screenshots (§10). Criteria are listed once; do not duplicate per section.
- **MUST 9.11** — **No debug / dev artefacts** — no `Log` overlays, no leftover `androidx.compose.ui.tooling.preview.Preview` debug strings, no `// TODO` placeholder text rendered into the UI.
- **MUST 9.12** — **Baseline integrity** — `git status <module>/screenshots/` after a record run shows **only new files**. Any modified existing screenshot is a regression on a previously-migrated screen and requires explicit user approval, noted in the Stage 8 report.
- **SHOULD 9.13** — **Snapshot is deterministic** — re-running the test produces a byte-identical PNG. Sources of nondeterminism (animation frame, current time, random colors) are stubbed.

Failures here mean the Composable is broken at the function level — fix before going to device (Stage 6). A passing Roborazzi sanity does **not** imply Stage 6 will pass; it only means it is worth running.

## 10. Scenario-by-scenario device screenshot diff (MUST — final approval gate)

Final approval is a side-by-side device screenshot comparison run through a **locked scenario catalogue** — the same reproducible user paths captured both before and after migration. Roborazzi (§9) is only sanity; it does not substitute this gate. States are what the screenshot shows; scenarios are the paths that reach them. Fair comparison requires the same scenarios on both sides.

- **MUST 10.1** — `swarm-report/<slug>-scenarios.md` exists, written in Pre-flight, **locked before Stage 3**. Each scenario is a numbered entry with:
  - `state` — what the captured screen shows (Content / Loading / Error / Empty / Content variant).
  - `entry` — deterministic entry point (Demo Mode, deep-link, fragment graph, feature sample app, etc.).
  - `setup` — fixtures / stubbed ViewModel values / Koin overrides.
  - `steps` — user actions, numbered.
  - `capture` — explicit moment in the step list.
  - `device` — device model, API, orientation, density, theme, font scale.
- **MUST 10.2** — Scenario coverage is exhaustive for the screen: Content default + every Content variant (role, mode, data shape, theme) + Loading + every distinct Error condition + Empty (if applicable) + key input interactions (validation error, focused field, keyboard open). Coverage is enforced by the `## Coverage justification` checklist inside `scenarios.md` — see `references/scenario-catalogue.md` for the exact format and the grep gates. Missing a realistic scenario or unchecked category without `N/A because <reason>` → regression, reject.
- **MUST 10.3** — For every scenario `S<n>` in the catalogue, both `swarm-report/<slug>-baseline-S<n>.png` and `swarm-report/<slug>-compose-S<n>.png` exist, captured per the scenario's `device` line (identical config on both sides).
- **MUST 10.4** — `swarm-report/<slug>-screenshot-diff.md` exists with one table row per scenario: `Scenario | State | Baseline | Compose | Verdict | Notes`. Every verdict is PASS.
- **MUST 10.5** — Per-row acceptance (all four must hold for PASS):
  - Element order and visual hierarchy match baseline.
  - **Structure-preserving elements** (navigation affordances, interactive elements, primary-action placement) shift ≤ 4dp vs baseline without documented design reason. Spacing between content blocks is allowed to change when `Gap.*` tokens replace legacy hardcoded dp — record the delta in the diff Notes column; this is not a FAIL on its own.
  - Every interactive element from baseline is present in Compose with same affordance.
  - No regression in state transitions (Loading → Content, Error → Retry): no flicker, empty frames, or back-navigation breakage.
- **MUST 10.6** — Stylistic delta is expected and does **not** fail a row: new UI Kit changes colours / typography / icon set / component shape — **including a dark-to-light background shift** for screens the legacy XML rendered on dark `NewAlfaTheme.Main`. Failing rows are structural / interaction / layout regressions, not style updates.
- **MUST 10.7** — Compose-side screenshot for every scenario passes the universal visual criteria in §14. Baseline-side may legitimately fail some §14 items (the old design might have had poor contrast or crowded spacing — that is exactly why we migrate); the **Compose side must pass them all**.
- **MUST 10.8** — If a scenario step cannot be reproduced on the Compose build (missing affordance, different navigation graph, altered input validation), that is a structural regression — mark the row FAIL and return to `compose-developer` with the **scenario ID**, the failing step number, the diff note, and both PNGs. Do **not** adapt the scenario to match the Compose build; the scenario catalogue is frozen once Stage 3 starts (no scenarios added, removed, or renamed mid-pipeline — gaps discovered during Stage 6 escalate, not silently drop).

### Edge-to-edge device checks (mandatory — add to every scenario's Compose screenshot)

- **MUST 10.9** — **No content clipped by the system navigation bar at rest.** The Compose-side screenshot for every scenario must show that the last visible element is not cut, overlapped, or hidden by the navigation bar. If the screen has a bottom action button or a bottom sheet handle, it must be fully visible above the bar. Violation = FAIL row.

  How to verify: capture the screen in its default state, then look at the bottom edge. The last visible content element must have a clear gap between itself and the physical navigation bar (or home indicator on gesture-nav devices). No element may share pixels with the navigation bar overlay.

- **MUST 10.10** — **Scroll-to-end: last item fully visible above the navigation bar.** For every screen that has a scrollable list or a `LazyColumn` / `LazyRow` / `verticalScroll`, the Content-state scenario must include a `scroll to bottom` step. The captured screenshot must show the very last list item or content element fully visible — not partially hidden under the navigation bar. Violation = FAIL row.

  Steps to add to the scrollable-content scenario:
  1. Load Content state until data is visible.
  2. Scroll to the very bottom.
  3. Capture screenshot at the bottom position.

  Acceptance: last item fully inside the safe area. A partially obscured last item → FAIL; return to `compose-developer` to verify `contentPadding` on the `LazyColumn` / `LazyRow` carries the navigation-bar inset.

- **MUST 10.11** — **Status bar / NavigationBar title not overlapping.** The navigation bar title and action icons (rendered by UIKit `NavigationBar`) must not overlap with the status bar clock or icons. Verify in every non-fullscreen Content scenario: the top of the screen shows [status-bar area] → [NavigationBar title row] with clear separation. Violation = FAIL row.

- Any FAIL row blocks approval. Hand back to `compose-developer` with the scenario ID, diff note, and PNG pair.

## 11. No logic drift (MUST)

- **MUST 11.1** — No changes to `ViewModel` / `UseCase` / `Repository` / navigation routes / Koin modules. Mechanical gate:
  ```bash
  BASE=${BASE:-origin/develop}
  git diff --name-only "$BASE"..HEAD -- \
    "**/*ViewModel*.kt" "**/*UseCase*.kt" "**/*Repository*.kt" \
    "**/*Router.kt" "**/*Navigator*.kt" "**/*Module.kt" "**/di/**"
  ```
  Empty output = PASS. Any file listed → open its diff and justify in the report. IDE-only reformat on a logic file is still a modification — revert the formatter run.

- **MUST 11.2** — No new DI bindings added solely to satisfy the Composable. Pass existing state through; do not refactor state shape. Mechanical gate (requires `ast-index`):
  ```bash
  # Enumerate Koin / provides symbols declared in the diff; flag anything newly introduced.
  git diff --name-only "$BASE"..HEAD -- "**/*Module.kt" "**/di/**" | xargs -I {} ast-index outline {}
  ```
  Any *new* `factory { ... }` / `single { ... }` / `@Provides` / binding entry → MUST violation unless pre-existing and unchanged (verify with `git diff --unified=0`).

- **MUST 11.3** — Error / analytics / logging calls preserved at the same call sites.

## 12. CMP posture (SHOULD)

Guidance, not blocker. Do not contort code; record trade-offs in the report.

- **SHOULD 12.1** — Prefer `stringResource` / `painterResource` via compose resources when the feature is a KMP candidate. Otherwise Android resources are fine.
- **SHOULD 12.2** — Avoid `LocalContext` / `LocalConfiguration` where an equivalent composable token exists.
- **SHOULD 12.3** — Avoid `android.graphics.*`, `android.text.*`, `android.view.*` inside the Composable body.
- **SHOULD 12.4** — `dimensionResource(R.dimen.*)` is acceptable (keeps XML parity) but not CMP-portable — note in report when used.

## 13. Suppress / lint excludes (MUST)

Per project rule `feedback_no_suppress.md`:

- **MUST 13.1** — No new `@Suppress` annotations, no new `baseline.xml` entries, no new detekt excludes introduced to pass the checks. Fix the code instead. Any exception needs explicit user approval with justification.
- **MUST 13.2** — Stage 5 stored the output of `./gradlew :<module>:detekt` in the swarm-report folder (Stage 5 artefact); reviewer **reads that report** and confirms PASS. Do **not** re-run detekt — the orchestrator owns Stage 5 mechanical gates. Compose rules (`io.nlopez.compose.rules:detekt`) are configured in `config/detekt/detekt-compose.yml`. If the Stage 5 artefact is missing or shows any finding, Stage 7 is not runnable — bounce back to orchestrator.

## 14. Universal visual content criteria (MUST / SHOULD)

Applied by the reviewer to **every** screenshot — Roborazzi (§9) and device (§10). One source of truth; sections that own gates reference §14 instead of repeating criteria.

A screenshot fails if any MUST is violated. SHOULD items are reported as findings, not blockers.

### 14.1 Readability

- **MUST** — Every visible text is legible: not blurry, not truncated where the design does not call for ellipsis, not microscopic (UIKit `paragraph.*` / `headline.*` tokens; no inline `sp` smaller than the smallest token).
- **MUST** — No mojibake / question-mark glyphs (missing-font / broken-localisation symptoms).
- **MUST** — No raw resource keys (`!string/foo`, `key:foo.bar`) or template literals (`{0}`, `${name}`) leak through into the rendered UI.
- **MUST** — No placeholder content (`Lorem ipsum`, `TODO`, `Test`, `123`) in non-test snapshots / non-test states.
- **SHOULD** — Text wraps gracefully at narrow widths (no orphan single character on its own line, no awkward hyphenation).

### 14.2 Contrast & colour

- **MUST** — Text is comfortably readable at arm's length on the device screenshot — no strain, no guessing. Reviewer heuristic, not a pixel measurement.
- **SHOULD** — Text contrast meets WCAG AA (normal ≥ 4.5:1, large ≥ 3:1). Use a contrast-checker tool when the heuristic feels borderline; do not try to read exact ratios off a PNG by eye.
- **MUST** — Icons visually distinguishable from background — no near-transparent icons on a near-equal background.
- **MUST** — Disabled state visually distinct from enabled, but still recognisable as the same control (not a blank box).
- **MUST** — Selected / focused / pressed states visually distinct from resting state for any interactive element captured in such a state.
- **SHOULD** — No two semantically different elements share the same colour to the point of confusion (error red vs warning red ambiguous).

### 14.3 Layout & spacing

- **MUST** — Consistent padding from screen edges across the screen — no element flush against the edge unless intentional (full-width images / dividers).
- **MUST** — Spacing between groups looks intentional — no random gaps mid-content, no two visually distinct sections glued together with zero spacing.
- **MUST** — Alignment consistent: text rows that should share a left-edge actually do; numeric columns right-align; icons aligned with their labels' baseline / centre per design.
- **SHOULD** — No excessive empty regions without purpose.
- **SHOULD** — Density balanced — not crowded (cramped touch targets, walls of text without breathing room) and not wastefully sparse.

#### Edge-to-edge layout (system bars)

- **MUST** — **No content overlaps the system navigation bar.** In the screenshot, the last visible content element must not share pixels with the system navigation bar (gesture handle or button bar). A button row or list item partially hidden under the navigation bar overlay = MUST violation. Applies to every screenshot, in every orientation.
- **MUST** — **No content overlaps the status bar.** The top of the screen shows the status bar followed by the app's NavigationBar (title row), with no content peeking behind or inside the status bar area.
- **MUST** — **Scroll-to-end: bottom of list clears the navigation bar.** For any scrollable screen, scrolling fully to the bottom must reveal the last item **entirely above** the navigation bar with a visible gap. A last item partially clipped by the navigation bar overlay = MUST violation. Common fix: `contentPadding` on `LazyColumn` / `LazyRow` must include the navigation-bar inset (`PaddingValues(bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding())`).
- **MUST** — **No phantom bottom whitespace.** On non-scrollable screens, the area below the last content element and above the navigation bar should look intentional — typically filled with the screen's background colour (`AlfaTheme.colors.bg.primary`), not a transparent gap that reveals the Activity behind.

### 14.4 Element integrity

- **MUST** — No overlap between siblings outside intentional Z-stacking (text on text, icon over text, two buttons sharing pixels).
- **MUST** — No clipping by container or screen edges: no text cut mid-word, no icons sliced, no rounded corners flattened by an overlapping container.
- **MUST** — No element extends beyond its expected container (chip wider than its row, image overflowing its card).
- **MUST** — Interactive elements look tappable — Buttons / Chips / row affordances are substantial, not pixel-thin. Reviewer heuristic.
- **SHOULD** — Touch targets are ≥ 48dp on a side when measured in code (`Modifier.minimumInteractiveComponentSize()` or explicit size). Exact 48dp is not readable off a PNG by eye; enforce in code review, not screenshot review.
- **SHOULD** — Baselines align across a row of mixed text sizes when the design intent is alignment.

### 14.5 State clarity

- **MUST** — Captured state is **unambiguous**: a Loading snapshot shows a loading affordance and *only* that (no half-loaded content); an Error snapshot shows the error UI with its message; an Empty snapshot shows the empty composable; a Content snapshot shows populated UI.
- **MUST** — No partial / transitional state captured by accident (half-skeleton + half-content, fade-in mid-frame). If a transition is the subject, capture it deliberately and label it as such.
- **MUST** — Interactive elements look interactive — buttons have a Button affordance, clickable rows have a chevron / pressed-state hint / similar cue.

### 14.6 Brand / theme consistency

- **MUST** — All colours / typography / iconography come from AlfaTheme + abm-uikit (no Material purple/teal accents, no `Icons.Default.*`, no foreign typeface).
- **MUST** — Corner radii / shadows / elevation come from `CornerSize.*` / `ShadowSize.*` tokens — visible inconsistencies (some cards rounded, others square, no design reason) are violations.
- **SHOULD** — Within a single screen, button styles do not mix without semantic reason (don't use primary / secondary / danger interchangeably for the same role).

### 14.7 Debug & dev artefacts

- **MUST** — No debug overlays (`Log` text rendered as UI, layout-bounds rectangles, `?lib version`, dev mode banners).
- **MUST** — No editor-only artefacts (`@Preview` background colour leaks, tooling watermarks).
- **MUST** — No Compose runtime placeholder ("CompositionLocal not provided", "missing Modifier", red error box).

When the reviewer reports a §14 violation, cite the section, screenshot path, and a one-line description (`§14.4 — overlap of action button and balance text on compose-content.png`). Implementation agents fix and resubmit.

---

## Output format for reviewer

Return findings structured as:

```
### MUST (blockers)
- [rule N.X] <one-line description> — <file>:<line> — <evidence / grep hit>

### SHOULD (follow-ups)
- [rule N.X] <one-line description> — <file>:<line>
```

Empty MUST list → migration passes Stage 7.
