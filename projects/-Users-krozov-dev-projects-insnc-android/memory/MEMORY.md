# Project Memory — Insync 3.0 Android

> Всё ниже — реальное состояние ветки `development`, проверено аудитом 2026-03-02.
> Экспериментальные ветки (удалены) — не отражены.

## Actual State of `development` (audited 2026-03-02)

### Build Infrastructure
- `build-logic/convention/` — **пустой** (нет plugin-файлов, только `build.gradle.kts`)
- `buildSrc/` — только `GenerateNavArgsProguardRulesTask.kt`
- Все модули используют `alias(libs.plugins.android.library)` + `build_scripts/config_*.gradle`
- **Нет KMP**: нет `commonMain/`, `androidMain/`, `iosMain/` нигде

### Networking (реальное)
- **Ktor 3.2.3** — основной networking. `KtorModule.kt` в `:core` с 3 квалифицированными клиентами
- **Retrofit 3.0.0** — присутствует, экспортируется через `api()` из `:core`. Нужен для `DownloadService`
- Feature-модули используют Ktor (`client.post()`, `body<T>()`)

### Calendar / DateTime (реальное — PARTIAL, обновлено 2026-03-03)
- `InputDateModel` / `InputDateView` / `InputDatePeriodView` — **MIGRATED** (ветка `tech/calendar-to-kotlin-datetime`)
- Оставшиеся Calendar файлы: `CalendarSerializer.kt`, `CalendarUtils.kt` (core + new-core), nav-generated code
- Отдельный scope (не в текущей ветке): FinAssist Calendar models, `LoyaltyHistoryRequestBody`, server DTO mappers
- **59+ файлов** импортируют `kotlinx.datetime` — частично внедрено в new-core и новых фичах
- `CalendarUtils.kt` в `new-core/date-utils` всё ещё содержит `SimpleDateFormat`

### Java APIs (реальное — STILL PRESENT)
- `java.util.regex.Pattern` — **9 файлов** в `new-core/utils/validation/`, cardscan, 3DS
- `java.text.SimpleDateFormat` — **6 файлов** (analytics, date-utils CalendarUtils, mappers, ScreenshotSaver)
- `java.io.IOException` — намеренно в `GeneralApiException` (OkHttp compat)
- `java.text.DecimalFormat` — AmountFormatUtil, FileSizeUtil — DEFERRED

### Versions (реальные)
- Kotlin: 2.3.10, AGP: 9.0.0, Ktor: 3.2.3, Retrofit: 3.0.0
- kotlinx-serialization: 1.10.0, kotlinx-datetime: 0.7.1, Kotest: 6.x
- Coil: **2.7.0** (не 3.x)
- SKIE: не добавлен, kotlin-multiplatform: не добавлен

---

## KMP Migration Plan (NEW — 2026-03-02)

Дизайн: `docs/plans/2026-03-02-kmp-migration-design.md`
План реализации: `docs/plans/2026-03-02-kmp-migration-plan.md`

### Фаза 0: Pre-KMP блокеры (нужно сделать первым)
1. Создать convention plugin `InsyncKotlinMultiplatformPlugin.kt` в `build-logic/`
2. Завершить Calendar → kotlinx-datetime (EditDate, EditDatePeriod, CalendarSerializer)
3. Убрать `java.util.regex.Pattern` → Kotlin `Regex` (9 validator-файлов)
4. Убрать `SimpleDateFormat` из `new-core/date-utils/CalendarUtils.kt`
5. Добавить SKIE в `libs.versions.toml`

### Первые KMP-кандидаты после Фазы 0
| Модуль | Блокер |
|--------|--------|
| `protocol:data:source:error` | ✅ Готов (только IOException) |
| `new-core:utils:validation` | Pattern→Regex |
| `new-core:date-utils` | Calendar + SimpleDateFormat |
| `protocol:data:source:response` | Calendar в EditDate/EditDatePeriod |

---

## AGP 9.0 Gotchas (для будущих convention plugins)

- `CommonExtension` — NOT generic (нет type params, в отличие от AGP 8.x)
- `org.jetbrains.kotlin.android` plugin REMOVED — Kotlin встроен в AGP
- `isDebuggable` — только на `ApplicationBuildType`, не на общем `BuildType`
- `buildTypes(action)` — только на API types (`LibraryExtension`/`ApplicationExtension`), не impl
- Использовать `com.android.build.api.dsl.LibraryExtension` в `extensions.configure<>`
- `analytics` модуль: использовать `insync.android.library` (без flavors) — потребляется модулями без `mobileServices` dimension

---

## kotlinx-datetime 0.7.1 Gotcha (CRITICAL)

- `kotlinx.datetime.Clock` = deprecated typealias для `kotlin.time.Clock`
- `Clock.System` НЕ резолвится через typealias → использовать `import kotlin.time.Clock`
- `kotlinx.datetime.format` extension нужен для `LocalDateTime.format(...)` — отдельный импорт
- `LocalDate.plus(DatePeriod)` и `LocalDate.minus(DatePeriod)` — **extension functions** (не member!)
  → требуют `import kotlinx.datetime.plus` / `import kotlinx.datetime.minus`
- `@WriteWith<Parceler>` в `@Parcelize` — аннотация должна быть на **типе**, не на параметре:
  `val foo: @WriteWith<MyParceler> SomeType?` (НЕ `@WriteWith<MyParceler> val foo: SomeType?`)

---

## Key Architecture Facts

- `protocol/data/source/error` — нет Android-импортов (только `java.io.IOException`) → первый KMP-кандидат
- `GeneralApiException` extends `java.io.IOException` намеренно (OkHttp interceptors требуют)
- `@Parcelize` модели — оставлять как есть, не ломать NavArgs
- Nav args (SafeArgs generated) — всё ещё используют `Calendar`, мигрировать последними
- `paging` модуль — `androidx.paging` dependency → останется Android-only
- RxJava — только в `:core` legacy (4 файла), не блокирует KMP

---

## Code Style (IMPORTANT — always follow when writing code)

Следующие правила отключены в detekt (чтобы не мозолили глаза в CI),
но я **обязан** их соблюдать при написании кода:

- **ForbiddenExpressionBody** — не использовать expression body: `fun foo() = bar()`. Всегда блок `{ return bar() }`
- **ForbiddenSingleLineIfStatement** — не писать однострочные if: `if (x) doSomething()`. Всегда с фигурными скобками и переносом
- **IncorrectClassOrdering** — соблюдать порядок членов класса (companion last, properties before methods и т.д.)
- **MaxLineLength** — строки не длиннее **130 символов**

---

## MR Workflow

- `glab mr create --source-branch X --target-branch development --description "..."` (не `--body`)
- Blocking зависимости между MR — только через GitLab UI (API 404)
- Ветки: `tech/kmp-{NN}-{name}`, коммиты: `[KMP-{NN}] description`
- Основная ветка: `development`. Worktree всегда от `development`

---

## Kover 0.9.7 Setup (done 2026-03-05, MR !965)

### Architecture
- Convention plugin `insync.kover` applied via `InsyncAndroidLibraryPlugin` + `InsyncKotlinLibraryPlugin`
- Root project auto-aggregates via `subprojects { plugins.withId("org.jetbrains.kotlinx.kover") { dependencies.add("kover", sub) } }`
- `implementation(libs.kover.gradlePlugin)` (NOT `compileOnly`) — needed for runtime classloader

### Kover 0.9.7 DSL (critical — different from 0.8.x)
- Extension: `KoverProjectExtension` (not `KoverReportExtension`)
- Config: `extensions.configure<KoverProjectExtension> { reports { filters { excludes { ... } } } }`
- Common (all variants): `reports { filters { excludes { ... } } }` — used in `InsyncKoverPlugin`
- NO `koverReport { }` — that's 0.8.x API; NO `androidReports("gmsDebug")` — doesn't exist in 0.9.7

### Kover 0.9.7 XML format
- Generates **JaCoCo-format** XML: `<counter type="LINE" missed="N" covered="N"/>`
- NOT Cobertura (no `line-rate` attribute)
- GitLab CI artifact: `coverage_format: jacoco`
- Coverage extraction: `grep 'type="LINE"' report.xml | tail -1 | awk -F'"' '{printf "Total coverage: %.2f%%\n", 100*$6/($4+$6)}'`

### Flavor-less Android modules
- `insync.android.library` (without `InsyncAndroidLibraryFlavorsPlugin`) → only `debug`/`release`/`internal` variants
- Feature modules with flavors → have `gmsDebug`/`hmsDebug` variants

---

## Metro DI Migration — Key Architecture Facts (branch: tech/metro-di-migration)

### How Metro ViewModel map works
- `@ViewModelKey + @ContributesIntoMap(AppScope::class) + @Inject constructor(deps)` — standard pattern for non-SSH ViewModels
- Metro ALWAYS resolves constructor deps of `@ContributesIntoMap` classes (even without `@Inject`)
- `IViewModelDelegate` IS in Metro's graph via `ViewModelDelegateMetroModule` in `:core`
- `ViewModelAssistedFactory` pattern for SSH ViewModels requires Factory `@Inject constructor` deps to ALL be in Metro's graph — but most app repos are Hilt-only, so this pattern is BLOCKED

### Metro Graph Boundaries (what IS and ISN'T in Metro's graph)
**IS in Metro's graph:**
- Coroutine dispatchers (migrated METRO-15)
- Settings, SharedPreferences, StateHolders (METRO-14)
- Ktor HttpClient, OkHttp, Retrofit stacks (METRO-13, 16)
- Analytics engines (METRO-18), EventBus, OnboardingDeps, PlateSettings (METRO-19)
- IViewModelDelegate chain: IRetryManager, IViewModelErrorManager, IViewModelDownloadManager (METRO-20)
- DownloadService (qualified + unqualified) via DownloadMetroModule
- Context via AppModule, Application via AppGraph.Factory
- Auth API services (METRO-17)

**NOT in Metro's graph (Hilt-only):**
- Feature-specific API services (AliasBannerApiService, ElectronicDocumentApiService, etc.)
- Feature repositories provided via `@Binds`/`@Provides` in Hilt `@Module` classes
- FileRepository (even though it has `@Inject constructor`, adding it as direct ViewModel dep fails — investigation pending)

### ViewModels deferred for future METRO tasks
- `MainActivityStateViewModel` (needs IMainPageAnalytics, DesktopBadgesRepository)
- `AliasBannerViewModel` (needs AliasBannerApiService — Hilt-only)
- `DocAgreeBlockViewModel` (needs FileRepository as direct dep — Metro fails, root cause unclear)
- `ElectronicDocumentOrderListViewModel` (needs ElectronicDocumentApiService)
- `MainActivityStateViewModel`, `AliasBannerViewModel`, `DocAgreeBlockViewModel`, `ElectronicDocumentOrderListViewModel` remain as `@HiltViewModel`

### Current State (METRO-32, 2026-03-07)
- ~105+ ViewModels in Metro (93 migrated in METRO-32), remaining @HiltViewModel are app/ VMs
- Git branch: `tech/metro-di-migration`, last commit METRO-32

### METRO-32 Key Fixes (2026-03-07)
- **`internal` Metro modules in `:core` are INVISIBLE to AppGraph in `:app`** — Metro's compiler plugin rejects cross-module contributions from `internal` objects. Must be `public`.
- **Exception**: modules exposing `internal` types (e.g. `AliasBannerApiMetroModule` → `AliasBannerApiService`) MUST stay `internal` — Kotlin won't allow public function returning internal type.
- **`@javax.inject.Inject` NOT recognized by Metro** without `includeJavaxAnnotations()`. Classes with only `@javax.inject.Inject` (like `FileRepository`) need explicit `@Provides` in a Metro module.
- `FileRepository` explicit `@Provides` added to `ViewModelDownloadManagerMetroModule`

### HiltMetroBridgeModule pattern
- Bridges Metro → Hilt (one-way): Metro-provided bindings made available to Hilt via `@Module @InstallIn(SingletonComponent::class)`
- There is NO Hilt → Metro bridge (Hilt modules are NOT accessible from Metro's graph)

---

## currentDate
Today's date is 2026-03-10.

## Feedback

- [Always cover new code with unit tests](feedback_test_coverage.md) — write tests proactively for new logic; notify if not feasible

---

## Test Account (emulator-5556)
- Phone: 375258703136 → enter as `258703136` in +375 field
- Passport ID: 7826065E071BB0
- SMS code: 11111
- PIN: 1122
- Credentials file: `/Users/krozov/Documents/INSNC Test User.txt`
- To reset app for fresh login: `adb -s emulator-5556 shell pm clear by.alfabank.insync3.debugx`
