# Fragment wiring patterns

Loaded during Stage 4. Three canonical patterns for hosting a Compose screen inside an existing Fragment. Pick per `## Wiring pattern` recorded in the plan (Stage 1).

## Selection

| Base class structure | Pattern |
|---|---|
| Plain `Fragment()` or base only uses `onDestroyView` | **A** — `onCreateView` returns `ComposeView` |
| Base owns `onViewCreated`, has non-content children in XML (app-bar, toolbar) | **B** — keep XML, replace content area with `<ComposeView>`, wire in `onViewCreated` |
| Base calls abstract hooks (`initView()`, `onBack()`, `onNext()`, etc.) | **C** — create `ComposeView` inside the abstract content callback; other callbacks untouched |

All three use `ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed`. Existing `onViewCreated` calls (`setTitle`, `setDisplayHomeAsUpEnabled`, `observeStepperViewModel`, navigation observers) stay completely untouched.

The Fragment's `setContent` owns `AlfaTheme { Box(fillMaxSize + background) }` — the composable itself does not wrap. Same rule for all three patterns.

## Pattern A — pure ComposeView host

Fragment extends plain `Fragment()` (no base UI). `onCreateView` returns:

```kotlin
ComposeView(requireContext()).apply {
    setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
    setContent {
        AlfaTheme {
            Box(Modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary)) {
                <Screen>Content(
                    state = viewModel.state.collectAsStateWithLifecycle().value,
                    onAction = viewModel::onAction,
                )
            }
        }
    }
}
```

Reference: `core-ui-components/sample/.../ComposeExampleFragment.kt`.

## Pattern B — keep XML shell, embed ComposeView

Fragment extends `BaseAlfaFragment(R.layout.<legacy_xml>)`. **`kotlin-engineer` modifies the XML**: replace the old content area with

```xml
<androidx.compose.ui.platform.ComposeView
    android:id="@+id/composeView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

keeping any app-bar / toolbar siblings untouched. Then in `onViewCreated`, **after** all base lifecycle calls:

```kotlin
viewBinding.composeView.apply {
    setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
    setContent {
        AlfaTheme {
            Box(Modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary)) {
                <Screen>Content(
                    state = viewModel.state.collectAsStateWithLifecycle().value,
                    onAction = viewModel::onAction,
                )
            }
        }
    }
}
```

Reference: `settings/app-settings/.../AllSettingsFragment.kt`, `auth/auth-impl/.../SetupGraphicalKeyFragment.kt`.

## Pattern C — inject into base callback

Fragment extends a base that owns `onCreateView`/`onViewCreated` and calls abstract hooks (`initView()`, `onBack()`, etc.). Same idea as Pattern A, but the insertion point is the abstract callback the base invokes. **Base class stays completely untouched.**

**Safety check.** Verify in the base class that `initView()` is called from `onViewCreated` or later (after inflation). If it is called from `onAttach` or `onCreate` (before `onCreateView` inflates the view), `requireView()` will throw — use Pattern B instead. (`onActivityCreated` is post-inflation and safe, though deprecated.)

### Preferred path (XML-first)

`kotlin-engineer` modifies the legacy XML: replace the content area with

```xml
<androidx.compose.ui.platform.ComposeView
    android:id="@+id/composeView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

Then wire in `initView()`:

```kotlin
override fun initView() {
    binding.composeView.apply {
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        setContent {
            AlfaTheme {
                Box(Modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary)) {
                    <Screen>Content(
                        state = viewModel.state.collectAsStateWithLifecycle().value,
                        onAction = viewModel::onAction,
                    )
                }
            }
        }
    }
}
```

### Fallback (XML cannot be modified)

Shared-layout cases only. Add a `ComposeView` programmatically — **always supply `MATCH_PARENT × MATCH_PARENT` layout params**, otherwise the view will be `WRAP_CONTENT` and may render at 0dp in weighted containers:

```kotlin
override fun initView() {
    ComposeView(requireContext()).also { composeView ->
        (requireView() as ViewGroup).addView(
            composeView,
            ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        composeView.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        composeView.setContent {
            AlfaTheme {
                Box(Modifier.fillMaxSize().background(AlfaTheme.colors.bg.primary)) {
                    <Screen>Content(
                        state = viewModel.state.collectAsStateWithLifecycle().value,
                        onAction = viewModel::onAction,
                    )
                }
            }
        }
    }
}
```

`initViewModel()`, `onBack()`, `onNext()`, `onClose()` — left **exactly as-is**.

**Fallback edge case.** `requireView()` cast to `ViewGroup` fails if the root is a single non-group view (rare — plain `TextView`, `ImageView`, or an already-converted `ComposeView`). If this is the case, (a) wrap the legacy root in a `FrameLayout` in the XML and switch to Pattern B (preferred), or (b) escalate to the user — a non-ViewGroup root with an `initView()`-owning base cannot be wired without modifying the base class, which is a non-negotiable #1 violation.

Reference pattern: `auth/auth-impl/.../registration/presentation/steps/` concrete `*StepFragment` subclasses (verify the file exists via `ast-index class` before using).
