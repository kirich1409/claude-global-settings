# Project Memory: Alfa-Kassa-Android

## Repository constraints
- **Nexus-only**: `settings.gradle.kts` uses `FAIL_ON_PROJECT_REPOS`. All deps via `nexus.alfabank.by/repository/maven-public/`.
- `buildSrc/settings.gradle.kts` mirrors the same Nexus-only constraint for buildSrc deps.
- `pluginManagement` in root settings also includes `gradlePluginPortal()` as fallback for plugins.

## Static analysis setup (done Feb 2026)
- `.editorconfig` — root, 160 chars line length for kt/kts; disabled rules: `filename`, `no-wildcard-imports`, `comment-wrapping`
- **ktlint** 12.1.2 plugin (ktlint binary 1.5.0) — applied via `subprojects { apply(plugin="org.jlleitschuh.gradle.ktlint") }` in root build.gradle.kts
- **detekt** 1.23.7 — applied via `subprojects { apply(plugin="io.gitlab.arturbosch.detekt") }`; config at `config/detekt/detekt.yml`; baselines per-module at `<module>/config/detekt/detekt-baseline.xml`; uses `buildUponDefaultConfig=true`
- **Android Lint** — in `app` only; baseline at `app/lint-baseline.xml`; configured with `abortOnError=true`
- **Kover** 0.9.7 — applied to root + `:app`; root aggregates `:app` via `dependencies { kover(project(":app")) }`; per-module: `koverHtmlReportDebug`; aggregated: `koverHtmlReport`
- Aggregating task: `./gradlew codeQuality` → runs ktlintCheck + detekt + lintDebug for all modules
- `./gradlew ktlintFormat` — auto-formats; `./gradlew ktlintCheck` — check only

### Baseline commands (re-run after code changes)
```bash
./gradlew detektBaseline          # IMPORTANT: run after ktlintFormat, baselines change after format
./gradlew :app:updateLintBaseline
```

### detekt config notes
- `formatting` section removed (requires detekt-formatting artifact)
- `exceptions>ThrowsCount` removed (does not exist in 1.23.7)
- `style>ThrowsCount` kept with max=5

## Test dependencies (added Feb 2026)
- **MockK 1.13.14** added as `testImplementation` — supports final Kotlin class mocking without agent on Java 17 + Android unit test env
- Test dirs: `app/src/test/kotlin/by/rdigital/cashbox/android/core/`, `core/currency/`, `core/hw/`, `core/utils/`, `core/extention/`, `domain/alfa/pojo/`, `data/db/`
- Existing Mockito-Kotlin 1.6.0 stays for `AppCommandInputDataValidatorTest`
- **IMPORTANT**: `mockk { every { toString() } ... }` does NOT work — `toString()` not interceptable. Use anonymous object implementing interface instead (see MinMaxFilterTest)
- For Android `Spanned` interface in tests: implement as anonymous object with full CharSequence impl
- Total tests as of Mar 2026: ~150+ unit tests, 0 failures

## Coverage philosophy (established Mar 2026)
- **Goal**: honest coverage of genuinely testable code — NOT inflating numbers with theater tests
- **Exclude** from Kover: ViewModels (UI), hardware drivers (PAX/BLE), Room/HTTP repos (integration), fiscal ops (AlfaOpenShiftUseCase), print use cases (legal compliance), DataBinding generated, Dagger generated, Android SDK wrappers (Context, AlfaMarket SDK, NeptuneLiteUser)
- **Test** use cases with pure RxJava chains, POJOs, extension functions with no Android context, input filters, data mappers
- **Do NOT modify production code** to add tests — user must approve any changes to `app/src/main/`
- Current coverage: **86.7%** on genuinely testable code (3304 total measured lines)
- Remaining misses: `ExtentionsKt` 399/793 (Android-context half can't be unit tested — acceptable 50% on that file)

## Kover convention plugin (done Feb 2026, refined Mar 2026)
- `buildSrc/build.gradle.kts` — adds `kover-gradle-plugin` as `implementation(libs.kover.gradle.plugin)` + forces `org.jetbrains:annotations:26.0.2` (transitive dep not in Nexus cache)
- `buildSrc/settings.gradle.kts` — shares `libs` version catalog via `versionCatalogs { create("libs") { from(files("../gradle/libs.versions.toml")) } }`
- **`buildSrc/src/main/kotlin/KoverExclusions.kt`** — единый список исключений (object KoverExclusions); используется в convention plugin И в корневом build.gradle.kts
- `buildSrc/src/main/kotlin/kover-convention.gradle.kts` — applies kover + `classes(KoverExclusions.classes)` (без дублирования)
- `app/build.gradle.kts` — uses `id("kover-convention")` instead of `alias(libs.plugins.kover)` + no inline kover{} block
- Root `build.gradle.kts` — uses `id("org.jetbrains.kotlinx.kover")` WITHOUT version + `kover { reports { filters { excludes { classes(KoverExclusions.classes) } } } }` для агрегированного отчёта
- **ВАЖНО**: Kover НЕ наследует фильтры подмодулей в агрегированный отчёт — нужно явно добавлять в корень
- Per-module report: `./gradlew koverHtmlReportDebug` → `app/build/reports/kover/htmlDebug/index.html`; XML: `app/build/reports/kover/reportDebug.xml`
- Aggregate report: `./gradlew koverHtmlReport` → `build/reports/kover/html/`; XML: `build/reports/kover/report.xml`
- Новый модуль с тестами: добавить `id("kover-convention")` + `kover(project(":module"))` в root dependencies

### Kover pattern tips
- `"**.generated.callback.*"` — use `**` prefix to match full package paths with prefix (NOT `"generated.callback.*"`)
- `"**.*_Factory\$*"` — needed for Dagger `_Factory$InstanceHolder` inner classes
- `"**.*\$CREATOR"` — Parcelable CREATOR static fields (Android SDK generated)

## Architecture reminders
- MVVM + Dagger 2 field injection (`@Inject lateinit var`) — standard pattern, NOT a bug
- Dagger uses `Map<Class, Provider<ViewModel>>`, NOT ViewModelProvider
- Navigation: `BaseNavigator` interface implemented by Activity; VMs call `navigator?.openSomething()`
- RxJava lifecycle: `.untilDestroy(rxLifecycle)` operator
