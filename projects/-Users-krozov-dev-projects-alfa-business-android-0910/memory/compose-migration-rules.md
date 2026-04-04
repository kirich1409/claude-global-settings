# XML→Compose Migration: Adaptation Rules

## Rule 1: Dark-background screens need AlfaTheme(mode = Mode.Dark)

**Problem**: Screens that have a dark window background (e.g. `NewAlfaTheme.Main` with `bg_1.webp`)
appear visually broken when wrapped in `AlfaTheme { }` (Light mode default).

**Root cause**: In Light mode, `specialBg.component = Color(0x110B1F35)` — only 6.7% opacity.
When the window background is dark (`#0B1F35`), TextField containers become invisible.
Also, `text.primary = Color(0xFF0B1F35)` (dark) on dark background = invisible text.

**Light vs Dark mode color comparison**:
| Token | Light mode | Dark mode |
|-------|-----------|-----------|
| `specialBg.component` | `0x110B1F35` (6.7% dark) | `0x26FFFFFF` (15% white) |
| `text.primary` | `0xFF0B1F35` (dark navy) | `0xFFFFFFFF` (white) |
| `text.secondary` | `0xB20B1F35` (70% dark navy) | `0xB2FFFFFF` (70% white) |
| `bg.primary` | `0xFFFFFFFF` (white) | `0xFF0B1F35` (dark navy) |

**Screens that use dark window background**: Login/auth screen (`NewAlfaTheme.Main`)

**Fix**: Every `ComposeView` fragment on a dark-background screen must use `AlfaTheme(mode = Mode.Dark)`.
This includes ALL fragments injected into that screen:
- The host Fragment (e.g., `CommonEnterFragment`)
- Every widget/content Fragment injected via DI (e.g., `InputLoginFragment`, `InputDemoFragment`)

```kotlin
// WRONG — invisible on dark background
AlfaTheme {
    MyScreen(...)
}

// CORRECT for dark-background screens
AlfaTheme(mode = Mode.Dark) {
    MyScreen(...)
}
```

**Import needed**: `import by.alfabank.uikit.theme.Mode`

## Rule 2: AndroidView child fragments start fresh Compose context

When a Fragment is injected into an `AndroidView` container inside another Fragment's Compose tree,
the child Fragment's `ComposeView` starts a **fresh Compose context** — it does NOT inherit the
parent's `AlfaTheme`. Each child Fragment's `ComposeView` must independently specify the correct
`AlfaTheme` mode.

## Rule 3: UIKit TextField visual behavior

UIKit `TextField` is an **outlined rounded-corner** component:
- `ContainerCornerRadius = 10.dp`
- When unfocused: `borderThickness = 0.dp` (NO visible border!)
- Container color: `specialBg.component` (from `TextFieldColors.default()`)
- In Light mode: container is nearly transparent → invisible on dark backgrounds

`TextFieldColors` constructor is `internal` — cannot create custom instances from outside the module.
Use `AlfaTheme(mode = Mode.Dark)` to get appropriate colors for dark-background screens.

## Rule 4: Static colors are safe on dark backgrounds

`AlfaTheme.colors.static.text.primaryLight = Color(0xFFFFFFFF)` — constant white regardless of mode.
Use `static.*` colors when you need guaranteed contrast (e.g., text on logo, fixed-color overlays).

## Rule 6: Injected widget fragments must NOT use `fillMaxSize()`

When a Fragment is injected via `injectWidget(PresentationInjector(...))` into a Compose
`AndroidView` container, its root composable must NOT use `Modifier.fillMaxSize()` or
`Modifier.fillMaxHeight()`. These expand the fragment's view to fill all available measurement
space (up to full screen), even when the container uses `wrapContentHeight()`.

**Problem**: In a Compose `AndroidView` with `wrapContentHeight()` inside a `Column`, the Android
view is measured with AT_MOST = large height. A fragment using `fillMaxSize` fills this large space,
making the container report a huge height (e.g., 381dp for a 56dp button).

**Fix**: Replace `Modifier.fillMaxSize()` with `Modifier.fillMaxWidth()` in the top-level composable
of any fragment that is injected as a widget into the CommonEnterScreen containers.

```kotlin
// WRONG — expands to fill container's AT_MOST measurement space
Column(modifier = Modifier.fillMaxSize()) { ... }

// CORRECT — wraps content vertically, fills only horizontally
Column(modifier = Modifier.fillMaxWidth()) { ... }
```

**Example fix**: `RootMicroserviceFragment.kt` → `RootMicroserviceScreen` Column.

**Rule scope**: Any fragment implementing `EnterWidgetModel.injectWidget()` that creates a ComposeView.

## Rule 7: Check `windowBackground` in AndroidManifest to determine theme mode

Look at the Activity's `android:theme` in `AndroidManifest.xml`, then find that style in `styles.xml`.
If `android:windowBackground = @drawable/bg_*` (dark gradient), use `Mode.Dark`.
If `android:windowBackground = @color/white` or light color, use `Mode.Light` (default).

Files to check:
- `auth/auth-impl/src/androidMain/AndroidManifest.xml`
- `core-ui-components/ui-components/src/androidMain/res/values/styles.xml`
