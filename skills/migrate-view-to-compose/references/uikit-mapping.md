# View → Compose (AlfaTheme / abm-uikit) mapping

Authoritative lookup for Stage 1 of the migration. Covers **standard Android View widgets** (framework / AppCompat / Material / AndroidX). Every View in the source XML must map to a row below. If a View has no row — it is a gap → Stage 2 (`missing-components-decision.md`).

For **project-specific legacy custom Views** (`by.st.alfa.ib2.ui_components.*` — `AlfaInputView`, `LabeledSwitch`-style composites, legacy pickers etc.), see the dedicated lookup: **`legacy-view-mapping.md`**. Check that file first whenever the XML references a class from `by.st.alfa.ib2.ui_components.*` — a row there usually saves running the Missing-components gate for an already-known mapping.

## Import roots

**Core UIKit — `by.alfabank.uikit.components.*`** (artifact `by.alfabank.abml.android:design-system`, currently `1.10.3-2.10.0`):

| Package | What's there |
|---|---|
| `components` (root) | `Accordion`, `Checkbox`, `Chip`, `ChipGroup`, `CollapsingLayout`, `CollapsingScaffold`, `Comment`, `FinalView`, `Icon`, `Indicator` / `DotIndicator`, `PatternLock`, `RadioButton`, `Scaffold`, `SegmentedControl`, `StatusBadge`, `Steps` / `OrderedStep` / `UnorderedStep` / `StepConnector`, `Superellipse`, `Surface` / `BasicSurface`, `Switch`, `Text` / `TextBlock` |
| `components.account` | `AccountView`, `AccountContent` |
| `components.actionbutton` | `ActionButton` |
| `components.amount` | `Amount`, `AmountText`, `AmountHeadline` (display only — for **input** use `field.NumberField` or `TextField` + `NumberInputTransformation`) |
| `components.bottomsheet` | `ModalBottomSheet`, `ModalBottomSheetContent` |
| `components.button` | `Button`, `BasicButton`, `SectionButton`, `TextButton`, `MainButtonBox` |
| `components.calendar` | `DatePicker`, `DatePickerDialog`, `DateRangePicker` |
| `components.card` | `BankCard`, `PaymentSystem` |
| `components.confirmation` | `OtpTextField`, `rememberOtpTextFieldState` |
| `components.data` | `DataView`, `DataContent` |
| `components.error` | `CompactError`, `FullscreenError` |
| `components.field` | `TextField`, `SecureTextField`, **`NumberField`**, `TextFieldScope` + `field.transformation.*` (`PhoneNumberInputTransformation` / `OutputTransformation` for +375, `NumberInputTransformation` / `OutputTransformation`, `ConstrainedInputTransformation`) |
| `components.file` | `FileUploadView` |
| `components.form` | `FieldContainer`, `FormControlLayout`, `Select` (form **layout** primitives, not text inputs) |
| `components.iconbutton` | `IconButton` |
| `components.iconview` | `IconView`, `IconViewShape` (+ badges) |
| `components.message` | `SystemMessage` |
| `components.navigation` | `NavigationBar` |
| `components.plate` | `Plate` |
| `components.popup` | `Popup`, `PopupContent` |
| `components.progress` | **`Spinner`** (indeterminate progress — not the Skeleton) |
| `components.pulltorefresh` | `PullToRefreshBox` |
| `components.skeleton` | `Skeleton`, `TextSkeleton` |
| `components.snackbar` | `Snackbar`, `BasicSnackbar`, `SnackbarHost`, `SnackbarVisuals`, `SnackbarDuration` (Material-like API) |
| `components.status` | `Status` |

Icons: `by.alfabank.uikit.Icons.Glyph.*`.

**Extension UIKit — `by.st.alfa.ib2.uikit_ext.components.*`** (project module `core-ui-components/abm-uikit-ext`, higher-level pre-configured widgets):

| Package | What's there |
|---|---|
| `uikit_ext.block` | `BlockTitle` (variants), `InfoBlock`, `CommonLimitsBlock`, `DetailsLimitBlock` |
| `uikit_ext.button` | `CategoryButton` |
| `uikit_ext.container` | **`StatefulContainer`** with `State.Content` / `State.Error` / `State.Loading` — ready-made pattern for screens that need all four states |
| `uikit_ext.document` | `DocumentListCard` |
| `uikit_ext.field` | `AgreementCheckbox`, **`AmountField`** (pre-configured currency input), `ChooseField`, `DetailsLineItem`, `DisabledTextField`, `InputField` (generic wrapper), `LabeledSwitch`, **`PhoneField`** (ready phone input), **`SearchField`** (ready search input), **`SmsCodeField`** (ready SMS/OTP), `SwitchInput` |
| `uikit_ext.filter` | `FilterChipRow`, `FilterChipItem` |
| `uikit_ext.image` | **`CircleImageLoader`** (round avatar with loading) |
| `uikit_ext.list` | `ExpandableListCard` |
| `uikit_ext.message` | `AutoDismissMessage` |
| `uikit_ext.navigation` | **`StepNavigationBar`** (multi-step navigation / payment flow) |
| `uikit_ext.pager` | `PageIndicator` |
| `uikit_ext.panel` | `BottomControlPanel`, `SlidingPanel` |
| `uikit_ext.picker` | `CurrencyPicker` |

**When to prefer ext over core:** prefer an ext-level widget (`AmountField`, `PhoneField`, `SearchField`, `SmsCodeField`, `InputField`) when the legacy XML ships a ready-made input with fixed behaviour. Drop to core (`TextField` + `transformation.*`) only when the legacy widget is genuinely bespoke or the ext widget does not match the spec.

## Core Views

| XML / View                                    | Compose replacement                                                       | Notes                                                                 |
|-----------------------------------------------|---------------------------------------------------------------------------|-----------------------------------------------------------------------|
| `TextView`                                    | `Text(text = ..., style = AlfaTheme.typography.*, color = AlfaTheme.colors.text.*)` | Never `fontSize = Xsp`. Pick style by role (see checklist §2).        |
| `ImageView` (vector icon)                     | `Icon(Icons.Glyph.<Name>M, tint = AlfaTheme.colors.graphic.*)`            | Glyph set: `CrossM`, `InformationCircleLineM`, `MagnifierM`, etc.     |
| `ImageView` (raster / drawable)               | `Image(painter = painterResource(R.drawable.*))`                          | Keep resource path; non-CMP. Mark `// TODO CMP` in CMP candidates.    |
| `Button` (Material/AppCompat)                 | `by.alfabank.uikit.components.button.Button(label, onClick, colors = ButtonColors.primary())` | Variants: `primary()`, `secondary()`, `tertiary()`, `danger()`.       |
| `MaterialButton` (outlined)                   | `Button(..., colors = ButtonColors.secondary())`                          |                                                                       |
| `ImageButton` / icon-only button              | `IconButton { Icon(Icons.Glyph.<Name>M, ...) }`                           | `contentDescription` required.                                        |
| `Checkbox` / `MaterialCheckBox`               | `by.alfabank.uikit.components.Checkbox`                                    | Do **not** build custom via Box + CheckmarkM.                         |
| `SwitchCompat` / `Switch`                     | `by.alfabank.uikit.components.Switch`                                      |                                                                       |
| `RadioButton`                                 | `by.alfabank.uikit.components.RadioButton`                                 |                                                                       |
| `Chip` / `ChipGroup`                          | `by.alfabank.uikit.components.Chip` / `ChipsGroup`                        |                                                                       |
| `TabLayout` (segmented)                       | `by.alfabank.uikit.components.SegmentedControl`                            | For segmented selector UX.                                            |
| `EditText` / `TextInputLayout`                | `by.alfabank.uikit.components.field.TextField` (`TextFieldState`-based; use `inputTransformation` for masks/validation, `outputTransformation` for display formatting — **not** `visualTransformation`). Password: `SecureTextField`. Phone (+375 Belarus): `TextField(inputTransformation = PhoneNumberInputTransformation, outputTransformation = PhoneNumberOutputTransformation)`. Numeric / amount: `TextField(NumberInputTransformation, NumberOutputTransformation)`. | Transformations live under `components.field.transformation.*`.       |
| `Spinner` / dropdown                          | `by.alfabank.uikit.components.form.Select`                                 | `Select` in `form` package is correct (it is a form primitive, not a text input). |
| `ProgressBar` (indeterminate)                 | `by.alfabank.uikit.components.progress.Spinner` for in-place spinners; `by.alfabank.uikit.components.skeleton.Skeleton` / `TextSkeleton` for content-shaped loading states | Pick per UX: `Spinner` = "something is loading, we don't know its shape"; `Skeleton` = "we know the shape of the content that will appear here". |
| `ProgressBar` (determinate)                   | *Gap candidate* — verify via UIKit lookup before declaring.               |                                                                       |
| `Toolbar` / `MaterialToolbar`                 | `by.alfabank.uikit.components.navigation.NavigationBar(title, navigationIcon = { BackButton { ... } })` | `BackButton` / `CloseButton` work only inside `NavigationBarScope`.   |
| `AppBarLayout` + CoordinatorLayout            | `Scaffold(navigationBar = { NavigationBar(...) }, content = { ... })`     | `by.alfabank.uikit.components.Scaffold` — not Material Scaffold.      |
| `BottomSheetDialog` / `BottomSheetFragment`   | `by.alfabank.uikit.components.bottomsheet.ModalBottomSheet`                | For modal bottom sheets.                                              |
| `SwipeRefreshLayout`                          | `by.alfabank.uikit.components.pulltorefresh.PullToRefreshBox`              |                                                                       |
| `DividerView` / `<View height=1dp bg=...>`    | `Box(Modifier.fillMaxWidth().height(1.dp).background(AlfaTheme.colors.border.primary))` | The new UIKit (`by.alfabank.uikit.components.*`) has no `Divider`. A legacy `by.st.alfa.ib2.ui_components.components.Divider` exists but uses `LegacyAlfaTheme` — forbidden for migration targets. Build the 1.dp `Box`. |
| `CardView` / `MaterialCardView`               | `by.alfabank.uikit.components.Surface(shape = RoundedCornerShape(CornerSize.M), color = AlfaTheme.colors.bg.secondary)` (use `BasicSurface` variant if a more primitive API is needed). | `Surface` is the first-party card primitive — prefer over custom `Box` composition. |
| `FloatingActionButton`                        | `by.alfabank.uikit.components.actionbutton.ActionButton` — or `uikit_ext.panel.BottomControlPanel` + `Button` when the design calls for a bottom-pinned primary action. | Do not use Material FAB.                                              |
| `Snackbar`                                    | `by.alfabank.uikit.components.snackbar.Snackbar` + `SnackbarHost` (the UIKit host, not Material). Fall back to `Plate` inside `Scaffold` only when the legacy UX was a persistent banner, not a transient snackbar. | Do not use Material `SnackbarHost` (the `androidx.compose.material.*` one). |
| `Toast` (Android)                             | Route through existing ViewModel side-effect channel; host handles display (keep current Toast invocation — lifecycle-owner side). | No change inside composable.                                          |
| `BottomNavigationView` / `NavigationBarView`  | *Gap candidate* — nav-infrastructure decision is out of scope for screen migration (see `project_navigation_decision.md`). | Do not migrate within a single screen task.                           |
| `SeekBar` / Material `Slider`                 | *Gap candidate* — check UIKit before proceeding.                          |                                                                       |
| `WebView` / `MapView` / `VideoView` / `SurfaceView` / `TextureView` | **Approval-gated** — wrap in `AndroidView { ... }` via missing-components Option C, only with explicit user approval recorded in the plan. Skeleton below. |                                                                       |
| Chat SDK view / third-party interactive widget | Same as above — Option C, approved, recorded.                             |                                                                       |

Wrapper skeleton for approval-gated widgets. **No `AlfaTheme { }` inside this composable** — `AlfaTheme` is owned by the Fragment's `setContent`, not by the composable body. The composable just hosts the `AndroidView`:

```kotlin
@Composable
private fun ChatContent(state: ChatState, onEvent: (ChatEvent) -> Unit) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context -> ChatView(context).apply { /* initial wiring */ } },
        update = { view -> view.render(state) },
        onRelease = { view -> view.release() },
    )
}
```

Roborazzi test for the `AndroidView`-rendering variant is skipped with a `// Roborazzi: AndroidView — not rendered in unit tests` comment (not the whole test file).

## Layout Views

| XML                                | Compose                                                  | Notes                                                        |
|------------------------------------|----------------------------------------------------------|--------------------------------------------------------------|
| `LinearLayout` vertical            | `Column(verticalArrangement = Arrangement.spacedBy(Gap.*))` | `spacedBy` over manual padding.                              |
| `LinearLayout` horizontal          | `Row(horizontalArrangement = Arrangement.spacedBy(Gap.*))` |                                                              |
| `FrameLayout`                      | `Box`                                                    |                                                              |
| `ConstraintLayout` (simple)        | `Column` / `Row` / `Box` if possible                     | Only fall back to `ConstraintLayout` compose when truly needed. |
| `ConstraintLayout` (complex)       | `androidx.constraintlayout.compose.ConstraintLayout`     | Non-CMP — flag in plan.                                      |
| `ConstraintLayout` with Barrier/Chain/Flow logic that cannot be preserved in compose `ConstraintLayout` | Missing-components Option C (`AndroidView` + approval). | Rare — re-evaluate compose `ConstraintLayout` first.         |
| `RecyclerView` (vertical list)     | `LazyColumn`                                             | Default. Migrate adapter view-holders to Composables.        |
| `RecyclerView` (horizontal list)   | `LazyRow`                                                |                                                              |
| `RecyclerView` (grid)              | `LazyVerticalGrid` / `LazyHorizontalGrid`                |                                                              |
| `RecyclerView` with adapter logic that cannot migrate without touching non-UI code | Missing-components Option C (`AndroidView` + approval). | Rare — most RecyclerViews migrate cleanly; only use when adapter holds logic that would violate non-negotiable #1. |
| `NestedScrollView` + children      | `Column(Modifier.verticalScroll(rememberScrollState()))` |                                                              |
| `ScrollView`                       | Same as above.                                           |                                                              |
| `ViewPager2` / `ViewPager` (legacy) | `HorizontalPager` / `VerticalPager` (`foundation.pager`) |                                                              |
| `TabLayout` (nav tabs)             | *Gap candidate* — verify Scaffold + SegmentedControl composition first. |                                                              |
| `Space` (XML placeholder)          | `Spacer(Modifier.size(Gap.*))`                           | Use spacing tokens, never literal dp.                         |
| `Guideline` / `Barrier` (ConstraintLayout) | Re-express with `Column` / `Row` / `Box`; keep `ConstraintLayout` compose only if original hierarchy truly requires it. | Fallback to compose `ConstraintLayout` is non-CMP — flag in plan. |
| `Group` (ConstraintLayout)         | No direct equivalent — rewrite visibility with state-driven branching (`if (visible) { ... }`). |                                                              |

## Extended UIKit (abm-uikit-ext, `by.st.alfa.ib2.uikit_ext.components.*`)

| Need | Use |
|---|---|
| Selector field (title + subtitle + chevron) | `uikit_ext.field.ChooseField` |
| Key/value details row | `uikit_ext.field.DetailsLineItem` |
| Section title (4 variants: informative / oneIcon / twoIcons / textAction) | `uikit_ext.block.BlockTitle*` |
| Agreement / terms checkbox | `uikit_ext.field.AgreementCheckbox` |
| Switch with label | `uikit_ext.field.LabeledSwitch` / `SwitchInput` |
| Read-only textfield style | `uikit_ext.field.DisabledTextField` |
| Generic pre-styled input wrapper | `uikit_ext.field.InputField` |
| Currency amount input | `uikit_ext.field.AmountField` |
| Phone input | `uikit_ext.field.PhoneField` |
| Search input | `uikit_ext.field.SearchField` |
| SMS / OTP code input | `uikit_ext.field.SmsCodeField` (or core `confirmation.OtpTextField`) |
| Pager dots | `uikit_ext.pager.PageIndicator` |
| Filter row of chips | `uikit_ext.filter.FilterChipRow` |
| Bottom sticky action panel | `uikit_ext.panel.BottomControlPanel` |
| Sliding panel (drawer-style) | `uikit_ext.panel.SlidingPanel` |
| Currency picker | `uikit_ext.picker.CurrencyPicker` |
| Category button | `uikit_ext.button.CategoryButton` |
| Document list card | `uikit_ext.document.DocumentListCard` |
| Expandable list card | `uikit_ext.list.ExpandableListCard` |
| Auto-dismissing toast-like message | `uikit_ext.message.AutoDismissMessage` |
| Step-navigation bar (payment flow) | `uikit_ext.navigation.StepNavigationBar` |
| Round avatar / icon loader | `uikit_ext.image.CircleImageLoader` |
| Info banner (structured) | `uikit_ext.block.InfoBlock` |
| Limits block | `uikit_ext.block.CommonLimitsBlock` / `DetailsLimitBlock` |
| Ready-made Loading / Error / Content screen states wrapper | `uikit_ext.container.StatefulContainer` with `State.Content` / `State.Error` / `State.Loading` |

Core UIKit shortcuts (kept here for quick lookup):

- Date: `components.calendar.DatePicker` / `DateRangePicker` / `DatePickerDialog`
- Error states: `components.error.CompactError` / `FullscreenError`
- Status badge: `components.StatusBadge`
- Key-value rows: `components.data.DataView` + `DataContent`
- Banner-style notice: `components.plate.Plate(colors = .neutral() / .positive() / .negative() / .attention() / .blue())`

## Tokens (use instead of raw dp / sp / hex)

- Spacing — `by.alfabank.uikit.tokens.Gap` enum (verified in source v1.10.3-2.10.0): `None` (0.dp), `Small3X` (2), `Small2X` (4), `Small1X` (8), `Small` (12), `Medium` (16), `Large` (20), `Large1X` (24), `Large2X` (32), `Large3X` (40), `Large4X` (48), `Large6X` (72), `Large7X` (96), `Large8X` (128). **There is no `Gap.XSmall` or `Gap.XLarge`** — use the exact names above.

  If you were reaching for:

  | Intuitive name | Use instead |
  |---|---|
  | `Gap.XSmall` (≈ 4 dp) | `Gap.Small2X` |
  | `Gap.XSmall` (≈ 8 dp) | `Gap.Small1X` |
  | `Gap.XLarge` (≈ 24 dp) | `Gap.Large1X` |
  | `Gap.XLarge` (≈ 32 dp) | `Gap.Large2X` |
  | `Gap.XXLarge` (≈ 40 dp) | `Gap.Large3X` |

- Radius — `by.alfabank.uikit.tokens.CornerSize` enum: `Unspecified`, `XXS` (2.dp), `XS` (4), `S` (6), `M` (8), `L` (12), `XL` (16), `XXL` (20), `XXXL` (24), `Circle` (CircleShape).
- Shadow — `by.alfabank.uikit.tokens.ShadowSize` enum: `Unspecified`, `XS`, `S`, `M`, `L`, `XL`. Apply with `Modifier.drowShadows(CornerSize.*, ShadowSize.*)` (note the misspelling `drowShadows` is the actual API — it is defined that way in source).

- Icons — `by.alfabank.uikit.Icons.Glyph.*`. Suffix convention: `M` (medium, default) / `S` (small) / `XxL` / compact / filled variants. **These common mental names do NOT exist** — use the real ones:

  | Intuitive name (DOES NOT EXIST) | Use instead |
  |---|---|
  | `Icons.Glyph.EditM` | `Icons.Glyph.PencilM` (alternates: `PencilLineM`, `PencilLightM`, `PencilUnderlineM`, `PencilS` for small) |
  | `Icons.Glyph.SearchM` | `Icons.Glyph.MagnifierM` (filled: `MagnifierFilledM`) |
  | `Icons.Glyph.InfoM` | `Icons.Glyph.InformationM` (in-circle outline: `InformationCircleLineM`; in-circle filled: `InformationCircleM`; small: `InformationS` / `InformationCircleS`) |
  | `Icons.Glyph.CloseXS` / `CloseS` | `Icons.Glyph.CrossS` for small; `CrossM` for medium; `CrossCircleM` / `CrossCompactM` for in-circle / compact variants |
  | `Icons.Glyph.BackM` | `Icons.Glyph.ArrowLeftM` (small: `ArrowLeftS`; medium-curved: `ArrowLeftCurvedM`) |
  | `Icons.Glyph.ForwardM` / `NextM` / `ChevronM` | `Icons.Glyph.ChevronRightM` (also `ArrowRightM` for a plain arrow) |

  When unsure, `find .../icons/**/*.kt | grep "val Icons.Glyph.<Prefix>"` in the extracted sources enumerates all variants of a given concept.
- Colors — backgrounds: `AlfaTheme.colors.bg.primary` / `.secondary` / `.tertiary`.
- Colors — text: `AlfaTheme.colors.text.primary` / `.secondary`; static on non-adaptive bg: `colors.static.text.primaryLight` / `.secondaryLight`.
- Colors — icons: `AlfaTheme.colors.graphic.primary` / `.secondary`.
- Colors — borders: `AlfaTheme.colors.border.primary`.
- Typography headlines: `AlfaTheme.typography.headline.xLarge` / `large` / `medium` / `small` / `xSmall`.
- Typography body: `AlfaTheme.typography.paragraph.primaryLarge/Medium/Small`, `secondaryLarge/Medium/Small`, `component`, `tagline`, `caps`.
- Typography accent/action: same shape as `paragraph`.

## Theme decision — default Light, Dark is the exception

The new UI Kit is light-first. The source `AlfaTheme` composable is defined as:

```kotlin
fun AlfaTheme(
    // always use Light mode by default
    mode: Mode = Mode.Light,
    ...
)
```

Translation: migrating a legacy screen from the old kit to the new kit means **moving it to Light** unless a design spec for this specific screen explicitly keeps it dark in the new kit. A dark XML baseline (`NewAlfaTheme.Main` / `bg_1.webp` / `AlfaText.WhiteText.*`) is old-kit visual language that is expected to disappear on migration — it is not a reason to wrap the Compose version in `Mode.Dark`.

When the XML baseline is dark, run the **Theme decision checkpoint** at Stage 1. The skill **recommends Light** and asks the user to provide a design-spec reference if they want Dark:

- **Light target** (default and typical): `AlfaTheme { ... }`, theme-adaptive tokens (`AlfaTheme.colors.bg.primary`, `text.primary`, etc.). Do not use `static.*Light` tokens.
- **Dark target** (rare, requires recorded design-spec reference): `AlfaTheme(mode = Mode.Dark) { ... }`. `AlfaTheme.colors.static.*Light` tokens are acceptable here.

Record the chosen answer + rationale under `## Theme decision` in the plan. If the XML baseline is already light (no theme forcing), skip the checkpoint — Light is the default and no record is needed.

Stage 7 reviewer cross-checks every `Mode.Dark` / `static.*` usage against the `## Theme decision` entry. No entry + `Mode.Dark` / `static.*` tokens used → MUST violation per checklist §1.5 / §1.6.

## Forbidden

- `androidx.compose.material.*` / `androidx.compose.material3.*` in screen code.
- `MaterialTheme.*`.
- `LegacyAlfaTheme` (`by.st.alfa.ib2.ui_components.theme.LegacyAlfaTheme`) — it reproduces the old visual style in Compose (lift-and-shift); this skill targets the new UI Kit. Use `AlfaTheme.*` tokens instead.
- `Icons.Default.*` / `Icons.Filled.*` / `Icons.Outlined.*`.
- Raw hex `Color(0x...)`, `Color.Red` / `Black` / `White`.
- `fontSize = Xsp`, `letterSpacing = ...sp` inline.
- `.padding(X.dp)` with magic numbers — always `Gap.*` or theme dimension.
- `Divider()` from Material — build the 1dp `Box` instead.
- **`AndroidView { }` for ordinary UI.** Permitted only for the approved complex-widget category (WebView, MapView, chat SDK, camera / media surface, complex RecyclerView, ConstraintLayout with Barrier/Chain) with explicit user approval per `missing-components-decision.md` Option C.
