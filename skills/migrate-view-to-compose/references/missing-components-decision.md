# Missing UIKit component — decision protocol

Triggers at Stage 2 of the workflow, once Stage 1 mapping has flagged a View with no direct UIKit equivalent in `uikit-mapping.md`.

**Hard rules**:
- Do not substitute Material.
- Do not inline a bespoke implementation without this protocol running to completion.
- `AndroidView { }` is **not** a default fallback. It is permitted **only** for complex third-party / native / functional-integration widgets (WebView, MapView, chat SDK views, camera / media surfaces, `RecyclerView` with non-portable adapter, `ConstraintLayout` with Barrier/Chain logic) **and only with explicit user approval recorded in the plan**. Ordinary UI (`TextView`, `Button`, layouts, simple lists) never qualifies — migrate to Compose.

## Step 1 — Search harder

Before declaring a gap, confirm the search is exhaustive:

```bash
ast-index class "<Candidate>"          # e.g. "ProgressIndicator"
ast-index symbol "<Candidate>"
ast-index search "<keyword>"
ksrc --help                            # for UIKit source inside .gradle
```

Look in:
- `by.alfabank.uikit.components.*`
- `abm-uikit-ext.*` — extension composables (see memory §abm-uikit-ext Components).
- Theme-level primitives (`AlfaTheme.colors`, `Gap`, `CornerSize`, `ShadowSize`).
- Existing migrated feature modules on `feature/compose-migration` — the component may already be realised as a screen-local helper reused nearby.

A common false positive: the component exists under a non-obvious name (e.g. `Plate` for info banner, `DataView` for key-value block, `StatusBadge` for label chip).

## Step 2 — Classify the gap

Pick the category that matches:

1. **Composition gap** — the need can be expressed by composing existing UIKit primitives (`Box` + `Text` + `Icon` + tokens). No new component required.
2. **Design-system gap** — the element is reused across the product and belongs in UIKit proper. Needs a request to the UIKit team.
3. **Screen-local gap** — genuinely one-off; a small local composable inside the feature module is acceptable with a TODO pointer.

## Step 3 — Produce options

For each option, record: effort (S/M/L), risk, CMP posture, reversibility.

- **Option A — Compose in place from UIKit primitives.** Best for category 1 — but **only when reuse-count is 1**. Run a project-wide reuse audit:

  ```bash
  grep -rl "<by.fully.qualified.ViewClass\|<id_or_pattern>" --include="*.xml" --include="*.kt" | wc -l
  ```

  If the result is **2 or more** (counting both migrated and not-yet-migrated screens that will need the same primitive), Option A is **forbidden** — promote to **Option A+** below. Wrap into a `private @Composable` inside the sibling screen file, named descriptively. Only tokens from `AlfaTheme`. Tag with `// Local composable — single use only, do not extract.`

- **Option A+ — Create shared component upfront.** Mandatory when reuse-count ≥ 2. Place the new Composable in `core-ui-components/ui-components/src/commonMain/.../components/<Name>.kt` (KMP commonMain — usable from any Android dependent module). Use the canonical name from the legacy View setters (`BottomControlPanel` ≈ `BottomControlPanelView`, `PickerRow` ≈ `TwoLineChooseView`). Compile, commit, and update the plan's `## Gap decisions` row to `DONE: <package>.<Name> committed in <sha>` **before** any Stage 3 agent starts on a screen that uses it. See SKILL.md §Stage 2.5 for the full protocol.
- **Option B — Request UIKit addition.** Best for category 2. File a UIKit ticket, agree on a temporary local composable living in `<feature>-impl/ui/local/` until the UIKit component lands, guarded by a TODO referencing the ticket id.
- **Option C — `AndroidView` wrapper (approved complex widget only).** Available **only** when the element is a complex third-party / native / functional-integration widget — WebView, MapView, chat SDK, camera / media surface, `RecyclerView` whose adapter cannot be preserved in `LazyColumn` without touching non-UI code, `ConstraintLayout` with Barrier/Chain logic that cannot be preserved in Compose `ConstraintLayout` without rewriting behaviour. Requires explicit user approval at the screen level. Roborazzi test for that state is skipped (`AndroidView` does not render in unit tests).

  **Approval request must justify the gap concretely.** For RecyclerView / ConstraintLayout cases, cite the exact adapter/handler symbols (classes, methods, callbacks) that would otherwise move to the `ViewModel` / `UseCase` layer if migrated — the reviewer cross-checks that claim against the actual adapter file at Stage 7. Hand-wave justifications ("too complex", "saves time") are rejected.

  **Wrapper skeleton** — keep `AlfaTheme { }` around the wrapper so surrounding tokens still apply; supply `update` and (when lifecycle matters) `onRelease`:

  ```kotlin
  AlfaTheme {
      AndroidView(
          modifier = Modifier.fillMaxSize(),
          factory = { context -> WebView(context).apply { /* initial config */ } },
          update = { webView -> webView.loadUrl(state.url) },
          onRelease = { webView -> webView.destroy() },
      )
  }
  ```

Never propose: "use Material3 `<Foo>`" — violates non-negotiable. Do not apply Option C to ordinary UI (`TextView`, `Button`, simple layouts) — those must be migrated.

## Step 4 — AskUserQuestion

Call `AskUserQuestion` with a single concrete question, recommended option first, alternatives on their own lines. Example templates:

Normal UI gap:

> Screen `<slug>` needs a `<what>` (`<XML tag>` maps to nothing in UIKit).
>
> **Recommended — (A) local composable from primitives.** `Box` + `Text` + `StatusBadge`; ~30 LOC; fully themed; low risk.
>
> Alternative — (B) request new `UIKit.<Foo>`; local stub until it lands; blocks this migration until stub is approved.

Complex third-party widget:

> Screen `<slug>` integrates `<WebView / MapView / ChatSdkView>`. No Compose equivalent exists; preserving functional integration is required.
>
> **Recommended — (C) `AndroidView` wrapper with approval.** Keep `<Widget>` inside `AndroidView { ... }`, wrap screen in `AlfaTheme { }`. Roborazzi skipped for this state.
>
> Alternative — skip migration of this screen for now; keep full XML until the widget has a Compose replacement.

Wait for answer. Do not proceed. Record the answer (including Option C approvals) in the plan.

### Mid-Stage-3 approval (late gap discovery)

If a gap surfaces only during Stage 3 implementation (the `compose-developer` hits the missing component without Stage 1 mapping catching it):

1. Pause the agent immediately.
2. Return to Stage 2 — run the search / classify / options / AskUserQuestion steps as usual.
3. Backfill the resolution into `swarm-report/<slug>-plan.md` (`## Gap decisions` / `## AndroidView exceptions`).
4. Only then resume Stage 3 with the decision in hand.

Approvals granted mid-flow that are not recorded in the plan are invalid — the Stage 7 grep-join will flag them as unauthorised.

## Step 5 — Record the decision

In `swarm-report/<slug>-plan.md`:

- Under `## Gap decisions` — every resolved gap (options A / B / C) with reasoning, location of the local composable or ticket id for UIKit, rollback note if UIKit eventually ships the real component.
- Under `## AndroidView exceptions` — every Option-C approval, one structured bullet per exception, in this exact shape so the Stage 7 reviewer can mechanically join it against the `AndroidView` grep hits:

  ```
  - widget: <ClassName> | file: <ScreenContent.kt> | reason: <one-line> | cited-symbols: <Adapter.method, Adapter.method2> | approved: YYYY-MM-DD
  ```

  Fields:
  - `widget` — Android widget class (`WebView`, `MapView`, etc.).
  - `file` — path (or filename) of the Composable hosting the `AndroidView`.
  - `reason` — one-line justification (functional integration, non-portable adapter, Barrier/Chain).
  - `cited-symbols` — for RecyclerView/ConstraintLayout exceptions, exact class.method names that block migration; `—` for native surfaces.
  - `approved` — date of the user's `AskUserQuestion` reply.

This record survives into Stage 8 close-out and into PROGRESS.md.

## Escalation

If the user is unavailable or unable to choose between options: stop, do not guess a fallback. Migration of this screen is blocked until a decision is made. Move on to another screen only if the current one is non-critical.
