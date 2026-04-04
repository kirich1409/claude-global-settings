# Project Memory

## Compose Migration Adaptation Rules
- See `compose-migration-rules.md` for full rules
- **Dark-background screens**: use `AlfaTheme(mode = Mode.Dark)` — default Light mode makes TextField containers (specialBg.component = 6.7% opacity) invisible on dark bg
- **Every injected child Fragment** on dark screens needs its own `AlfaTheme(mode = Mode.Dark)` — child ComposeViews don't inherit parent AlfaTheme
- Check `android:theme` in AndroidManifest → `styles.xml` `windowBackground` to determine if screen needs dark mode
- Screens with `NewAlfaTheme.Main` (bg_1.webp) need `Mode.Dark` — applies to login/auth screen

## UI Kit Theme API (AlfaTheme)
- Background colors: `AlfaTheme.colors.bg.primary/secondary/tertiary` (NOT `background`)
- Text colors (theme-adaptive): `AlfaTheme.colors.text.primary` / `.secondary` (most common in new code)
- Text colors (static, light-only): `AlfaTheme.colors.static.text.primaryLight` / `.secondaryLight` (both compile)
- Graphic/icon: `AlfaTheme.colors.graphic.primary` / `.secondary`  (NOT `colors.static.accent.primary` — doesn't exist)
- Border/divider: `AlfaTheme.colors.border.primary` (used by UIKit internally for dividers in SegmentedControl, DatePicker etc.)
- Static bg: `AlfaTheme.colors.static.bg.primaryDark` (for dark backgrounds)
- Typography headline: `AlfaTheme.typography.headline.xLarge/large/medium/small/xSmall`
- Typography paragraph: `AlfaTheme.typography.paragraph.primaryLarge/primaryMedium/primarySmall/secondaryLarge/secondaryMedium/secondarySmall/component/tagline/caps`
- Typography accent: `AlfaTheme.typography.accent.*` (same fields as paragraph)
- Typography action: `AlfaTheme.typography.action.*` (same fields as paragraph)
- DO NOT import `androidx.compose.foundation.layout.weight` — it resolves to internal. Use `Modifier.weight()` inside Column/Row scope without explicit import.
- See `patterns.md` for more details.

## Закрытый контур CI — только Nexus
- Все зависимости только через `https://nexus.alfabank.by/repository/maven-public/`
- Не добавлять `mavenCentral()`, `google()`, `gradlePluginPortal()` напрямую
- Robolectric SDK резолвится через Nexus — настроено в `AndroidBaseConfigurationPlugin` через `systemProperty("robolectric.dependency.repo.url", "https://nexus.alfabank.by/repository/maven-public/")`
- При падении тестов с `UnknownHostException` из `MavenArtifactFetcher` — это значит Robolectric пытается загрузить Android SDK из интернета; исправление уже есть в `AndroidBaseConfigurationPlugin`

## Gradle Tasks
- Compile: `./gradlew :module:compileDebugKotlin` (NOT `compileDebugKotlinAndroid` for library modules)
- Lint: `./gradlew :module:lintDebug`
- Detekt: `./gradlew detekt`
- Full build: `./gradlew :apps:abm-android:google:assembleDebug`

## UIKit Component API (Confirmed from Pilot)
- `Button`: import `by.alfabank.uikit.components.button.Button` (NOT just `components.Button`); params: `label=`, `colors=ButtonColors.primary()` / `ButtonColors.secondary()` etc.
- `CloseButton`: member function of `NavigationBarScope` — use inside `NavigationBar(navigationIcon = { CloseButton(onClick = ...) })`, NO explicit import needed
- `BackButton`: same scope as `CloseButton` — use inside `NavigationBar(navigationIcon = { BackButton(onClick = ...) })`
- `NavigationBar`: `by.alfabank.uikit.components.navigation.NavigationBar(title=, navigationIcon={})`
- `Scaffold`: `by.alfabank.uikit.components.Scaffold(navigationBar={}, content={})`
- R drawables in non-transitive mode: `by.st.alfa.ib2.ui_components.R.drawable.ic_rate_*` (module's own drawables are non-transitive, need fully-qualified R)
- **Divider**: NO public `Divider` composable in UIKit (`by.alfabank.uikit.components`). The only `Divider` there is `private fun` inside `SegmentedControl.kt`. `import by.alfabank.uikit.components.Divider` causes compile error. `by.st.alfa.ib2.ui_components.components.Divider` exists but uses `LegacyAlfaTheme` — crashes in Roborazzi tests under `AlfaTheme {}`. Solution: local `Divider` using `Box` + `AlfaTheme.colors.border.primary` + `height(1.dp)`. Candidate for extraction to shared module.
- `Icons.Glyph.CloseXS` does NOT exist → use `Icons.Glyph.CrossM`
- **Icons import pattern**: `import by.alfabank.uikit.icons.Icons` + `import by.alfabank.uikit.icons.glyph.<IconName>`. Usage: `Icons.Glyph.PlusM`
- `InfoM` does NOT exist → use `InformationCircleLineM`
- `SearchM` does NOT exist → use `MagnifierM`
- Available icons: `PlusM`, `CrossM`, `InformationCircleLineM`, `MagnifierM`, `ChevronDownM`, `ChevronRightM`, `CheckmarkM`, `ShareM`, `SlidersM`, `DoorOpenM`, `BellM`, `UserM`, `DocumentLinesM`, etc.

## XML→Compose Migration Rules
- После успешной миграции модуля — мержить в общую ветку (develop)
- Каждый модуль в отдельном worktree + отдельная ветка от develop
- DataBinding модули включены в миграцию (решение пользователя от 2026-03-04): cash_impl, reservations-impl, letter-to-bank-impl, acceptance-impl
- reference-impl и fx-deal-impl — уже мигрированы в wave10/reference и wave10/fx-deal
- Модули chat-impl и deal-registration-impl — отложены по решению пользователя
- currency-payments-impl — отложен: ~15 кастомных View без Compose-аналогов, ~2700 строк RxJava2 bindings, внешние layout-зависимости
- Исключение любого другого модуля — только с согласия пользователя

## XML→Compose Migration Status (as of compose-blocker-removal plan, 2026-03-04)
Fully migrated (0 non-structural XMLs):
  - requirements-without-acceptance-impl ✅
  - profile/questionnaire-impl ✅
  - letter-to-bank-impl ✅ (compose_item remains)
  - deposit-impl ✅
  - credit-loan-application-impl ✅
  - outgoing-requirements-impl ✅ (2 pure ComposeView wrappers remain)
  - credits/credit-impl ✅ (structural: compose_host + host_activity remain)
  - cards-impl ✅ (0 fragment XMLs; compose_item + local StepperPanel remain)
  - invoice-impl ✅ (compose_item only)

Camera/special cases (not migratable):
  - open-account-impl: activity_camera.xml (CameraX + PreviewView, no Compose equivalent)

Partially migrated (bridge pattern for remaining XMLs with no Compose equivalent):
  - cash_impl: 9 XMLs remain (AlfaSearchView/AlfaTabLayout/doc-sign-theme blocked; RecyclerView items)
  - reservations-impl: 8 XMLs remain (activity + 3 screens + compose_item + Views)
  - acquiring-impl: 8 XMLs remain (create_invoice forms — AmountInputView/NonAuthEditText/RatesView; RecyclerView items)
  - documents-host-impl: 10 XMLs remain (OldFilterView/AlfaDocumentView/HidingView — no Compose equivalents; Activity + View XMLs)

New shared components added to abm-uikit-ext (feature/compose-components branch):
  - BottomControlPanel, HorizontalSelectorField, DetailsLineItem (showDivider param)
  - BlockTitle (6 variants: None/Informative/OneIcon/TwoIcons/TextAction/OnSurface)
  - InfoBlock, CommonLimitsBlock, DetailsLimitBlock
  - Roborazzi tests: 43 golden screenshots across invoice-impl, acquiring-impl, documents-host-impl

Deferred (out of scope):
  - chat-impl, deal-registration-impl, currency-payments-impl
- Параллельный запуск: несколько агентов одновременно в разных worktree
- **RULE: Все worktree для агентов создавать в `.worktree/` внутри проекта (не в /tmp). Папка в .gitignore.**
- **RULE: Временные файлы — в `.temp/` внутри проекта. Папка в .gitignore.**
- После каждой миграции: compile + test + lint + detekt + Roborazzi record + review screenshots
- **RULE: RecyclerView как обёртка с ComposeView в элементах (без AndroidView) может временно остаться.** Это значит: `compose_item.xml` (содержащий только ComposeView) + header XML для RecyclerView-инфраструктуры — допустимы. Модуль считается мигрированным, если вся UI-логика в Compose.

## UIKit Migration Workflow Preferences
- **RULE: Roborazzi тесты + анализ скриншотов — ОБЯЗАТЕЛЬНЫЙ шаг любой миграции на Compose. Цикл: migrate → create Roborazzi tests → record goldens → analyze screenshots → fix UI issues → repeat until no remarks → commit.**
- Visual verification: Roborazzi screenshots ONLY (no emulator needed).
- Roborazzi is sufficient for visual acceptance — do NOT start emulator unless explicitly requested.
- **RULE: После каждой UI-правки запускать Roborazzi и проверять скриншоты. Если тестов нет — создавать.**
- **RULE: Весь UI мигрированный в Compose должен быть покрыт Roborazzi screenshot-тестами. Общие компоненты (deposits-common и т.п.) покрывать не обязательно.**
- **RULE: Миграция НЕ считается завершённой без Roborazzi тестов и анализа скриншотов. Агенты должны создавать тесты, записывать goldens, анализировать PNG и исправлять UI до тех пор, пока нет замечаний.**
- **Roborazzi record command**: `cd .worktree/<name> && ./gradlew :module:testDebugUnitTest -Proborazzi.test.record=true` (только debug; запускать из worktree, не из корня проекта)
- **Roborazzi LIMITATION**: `roborazzi-compose` 1.59.0 is KMP — does NOT resolve for non-KMP (`abm.android.libBase`) modules. Use only in KMP (`abm.kmp.androidLib`) modules. For non-KMP: skip Roborazzi tests or use `roborazzi-compose-android` explicitly.
- Roborazzi test setup pattern: plugin `abm.testing.roborazzi` + manifest `<activity android:name="androidx.activity.ComponentActivity" />` at `src/test/AndroidManifest.xml` (non-KMP) or `src/androidUnitTest/AndroidManifest.xml` (KMP)
- `useViewBinding = false` → also need `useAndroidResources = true` in android block to keep R class generation
- Wave 3 worktrees: `.worktree/wave3-notification`, `.worktree/wave3-deposits`, `.worktree/wave3-settings`, `.worktree/wave3-deposit`


## Roborazzi + AndroidView limitation
- `AndroidView` wrapping Material components (TextInputLayout, etc.) requires AppCompat/MaterialComponents theme in test context
- Adding `android:theme` to `ComponentActivity` in `src/test/AndroidManifest.xml` does NOT fix it — theme isn't applied to Compose rendering context in Roborazzi
- Solution: don't test Composables containing `AndroidView` with Material Views in Roborazzi; test those components manually or in UI tests

## abm-uikit-ext module (core-ui-components/abm-uikit-ext)
- Available Compose components: `ChooseField`, `AgreementCheckbox`, `LabeledSwitch`, `SwitchInput`, `DisabledTextField`, `PageIndicator`, `CalculatedSalaryBlock`, `FilterChipRow`, `BottomControlPanel`, `HorizontalSelectorField`, `DetailsLineItem`, `BlockTitle*` (6 variants), `InfoBlock`, `CommonLimitsBlock`, `DetailsLimitBlock`
- `ChooseField` (replaces `TwoLineChooseView`): `by.st.alfa.ib2.uikit_ext.components.field.ChooseField(value, onClick, label?, placeholder?, error?, trailingIcon?)`
- `AgreementCheckbox` (replaces `AlfaAgreementView`): `by.st.alfa.ib2.uikit_ext.components.field.AgreementCheckbox(text, checked, onCheckedChange, error?)`
- `ComposableParamOrder` rule: `modifier` must come before any optional params (default values) in `@Composable` functions
- Stateless Screen pattern for mutableStateOf: Fragment holds `mutableStateOf<T>`, observes LiveData, updates state → Screen receives plain values. No `observeAsState` (requires runtime-livedata dep)

## Migration Patterns
- **RULE: Programmatic views НЕ подходят. Только Compose.** Не создавать Toolbar/LinearLayout/FrameLayout программно в Kotlin — всё через ComposeView + Compose composables. AndroidView допустим ТОЛЬКО для структурных контейнеров (FrameLayout для Cicerone fragment transactions, WebView, ImageView для Picasso).
- Container activities (Cicerone nav): ComposeView + Compose UI + AndroidView(FrameLayout) только для fragment container
- Fragment container IDs: `View.generateViewId()` (not R.id)
- **ComposeView + child fragments**: when Fragment.onCreateView returns ComposeView with AndroidView containers, defer child fragment transactions via `view.post { }` — Compose AndroidView factories haven't run yet at onViewCreated time
- ViewCompositionStrategy for fragments inside decompose: use `DisposeOnDetachedFromWindow` (safer during slide animations)
- PatternView: AndroidView bridge (no Compose equivalent, C4)
- MessageDialog: kept as platform dialogs (not in Compose tree)
- Transitional bridge for complex forms: ComposeView + AndroidView inflating original XML via ViewBinding
- Inside `View.apply { }` block, `rootView` resolves to `View.rootView` (val) — use `this@ClassName.rootView` to access fragment property
- Drawables from ui_components: use `by.st.alfa.ib2.ui_components.R.drawable.*` (ic_close, ic_arrow_right, ic_road_map_*)
- StepperView: `stepsCount` is private (XML-only) — inflate from layout XML, don't create programmatically
- BottomSheetTitleView: constructor needs `(context, null)` not `(context)` — attrs param is not defaulted
- AlfaInputView: `maxLength`/`isSingleLine` set via XML attrs only — use `addFilter(InputFilter.LengthFilter(n))` or inflate XML
- BaseSearchActivity hierarchy: changed abstract `getLayoutId():Int` → `onInflateContent(inflater):View`; subclasses override `onInflateContent()` and set `_viewBinding` there
- KMP library (`abm.kmp.androidLib`) needing Compose: add `alias(libs.plugins.compose.compiler)` to plugins + `abm.designsystem` + `androidx.activity.compose` in `androidMain.dependencies`
- Non-KMP library (`abm.android.libBase`) needing Compose: add `compose.compiler` plugin + `abm.designsystem` in dependencies
- Library modules use `compileDebugSources` task (not `compileDebugKotlin`) for compile verification
- `kapt + compose.multiplatform` conflict: adding both fails `kaptGenerateStubs` — use only `compose.compiler` (not `compose.multiplatform`) in modules with kapt/DataBinding
- Shell heredoc zsh history expansion escapes `!` as `\!` — always fix with Python byte replacement or use quoted EOF heredoc
- Abstract base classes with layoutId constructor (BaseRsrvFragment, BaseDocumentFragment, BasePaymentFragment) — safest: override onCreateView in each concrete subclass; only modify base class if subclasses don't override onCreateView
- KMP + compose.multiplatform: only add if module is truly multiplatform; some KMP modules use kapt (DataBinding) and need only compose.compiler

## AGP 9.0 Migration (worktree: /tmp/claude-501/alfa-business-android-0910-agp9, branch: migrate/agp-9.0)
- AGP 9.0 enforces UNIQUE namespaces — google-variant modules sharing namespace with base → add suffix to packageId
- External libs (maps-utils-ktx+android-maps-utils, litert-support+litert-support-api) share namespace by design; fix: remove one or replace KTX wrapper
- `GenClassInfoLog.fromFile()` reads binding_classes.json with `Charsets.UTF_16` — write must also use UTF_16
- AGP 9.0 artifact type for databinding: `"android-databinding-class-log"` (NOT `"android-data-binding-base-class-log"`)
- Config Cache: don't capture `Project` in task closures; use `List<String>` paths + `List<File>` (pre-materialized via `.get().asFile`)
- `mustRunAfter("$depPath:taskName")` requires task to exist → filter dep paths by `file("src/androidMain/res/layout").exists()` first
- `base-recyclerview` changed `recyclerview` from `implementation` to `api` → consumers get RecyclerView 1.4.0 on compile classpath
- assembleDebug: BUILD SUCCESSFUL as of phase 5 commit (6fce21a3a9)
