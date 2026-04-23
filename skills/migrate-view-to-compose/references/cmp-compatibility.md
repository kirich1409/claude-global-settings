# CMP compatibility — guidance

Compose Multiplatform posture for the migration. **Guidance, not a blocker.** The user has said "try to make it CMP-friendly, but deviation is allowed". Use this file to nudge the implementation toward portability when the cost is near-zero, and to leave breadcrumbs for future KMP extraction.

## Prefer

- **Text resources** — keep `stringResource(R.string.*)` for Android-only modules. In modules already tagged for KMP (watch `build.gradle.kts` for `kotlin.multiplatform`), use compose-multiplatform `Res.string.<id>` if the infra is in place, otherwise leave Android and mark `// TODO CMP: stringResource`.
- **Images** — `Image(painter = painterResource(R.drawable.*))` is acceptable for Android-only. For KMP candidates, prefer vector UIKit icons (`Icons.Glyph.*`) that are already multiplatform.
- **State** — hoist state into plain Kotlin holders (`data class` / `sealed interface`). Reusable composables should accept state as parameters, not read from `LocalContext`. `ViewModel` stays Android-side; it is allowed as the hosting boundary.
- **Coroutines** — `kotlinx.coroutines.*` only. Avoid `AsyncTask`, `Handler`, Rx — those are legacy and Android-only anyway.
- **Time / formatting** — `kotlinx.datetime`, `kotlinx.serialization` when available. Android-only `java.time.*` is acceptable but flag it in the report if used in a KMP-candidate module.

## Avoid (inside the Composable)

- `LocalContext.current`, `LocalConfiguration.current`, `LocalView.current` — Android-only.
- `android.graphics.*`, `android.text.*`, `android.view.*`.
- `dimensionResource(R.dimen.*)` — not available in CMP. Prefer `Gap.*` / `CornerSize.*` tokens, which are multiplatform-friendly.
- `android.content.res.Resources`, `ContextCompat.*`, `AppCompatResources.*`.
- `ViewCompat`, `WindowInsetsCompat` — use Compose equivalents (`Modifier.windowInsetsPadding(...)`, `WindowInsets.systemBars`).

## Allowed even in CMP-candidate modules

- `ViewModel` from AndroidX — it is Android-side but is invoked at the Fragment boundary, not inside the shared composable. The composable receives state from it via `collectAsState()`.
- Resource access via wrappers — if the feature already uses a `ResourceProvider` / `StringProvider` abstraction, keep it.
- `painterResource(R.drawable.*)` when the drawable is PNG/vector that would not port to KMP regardless.

## Trade-off policy

Do not block the migration on CMP purity. If CMP posture forces a significantly more complex implementation, choose the simpler Android path and add a one-line note in the close-out report:

```
CMP deviations on <slug>:
- <file>:<line> — uses dimensionResource; needs token when KMP-extracted.
- <file>:<line> — reads LocalContext for Toast; move to ViewModel SideEffect on KMP move.
```

These notes compound into a future "CMP readiness" pass — they are cheap to record now, expensive to reconstruct later.

## Quick grep-audit (optional, for reviewer)

Non-blocking — produces a list of Android-only touchpoints:

```bash
grep -rnE "LocalContext|LocalConfiguration|dimensionResource|android\.(graphics|text|view)\." "$SCREEN_DIR" || true
```

Hits from this grep turn into **SHOULD 12.x** findings in the Stage 7 review, not MUST.
