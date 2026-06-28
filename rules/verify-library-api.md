# Verify Library API Before Code

## Verify library API before code

Обязательно перед Edit/Write кода с внешней библиотекой. Training data устаревает; existing project code = только используемый срез API, может быть legacy/антипаттерном.

**Три роли каналов — дополняют, не исключают; часто нужны параллельно:**
- **API truth** (сигнатуры, семантика, типы, альтернативы) — всегда при написании/правке кода с библиотекой.
- **Guides** (рекомендуемые паттерны, migration, codelabs, troubleshooting, «как принято») — для «как сделать X», «миграция A→B», незнакомого стека, нетривиальной интеграции.
- **Project style & versions** (стиль, pinned версии, подключённые модули) — всегда, отдельным проходом поверх внешних каналов; это **не** API truth.

`→` ниже = fallback внутри одной роли, **не** приоритет между ролями. Memorized signatures — **никогда** как источник.

**Композиция по стекам** (API truth + Guides — параллельно, если задача нетривиальна):
- **Android:** API truth = `ksrc` + `android docs` параллельно (jar + текущая рекомендация, не «или/или»). Guides = `android docs` + bundled Android CLI skills параллельно (skills = structured workflows для миграций/областей; docs = точечные guides/codelabs). Fallback: Context7 → WebSearch.
- **JVM/Kotlin/KMP/Gradle (не-Android):** API truth = `ksrc` primary → Context7 → WebSearch. Guides = Context7 (Kotlin покрыт неравномерно) → WebSearch. `ksrc` даёт только сорсы — для «как принято» нужен второй канал.
- **Frontend/JS/TS:** оба канала — Context7 primary → WebSearch.
- **Other (Python/Go/Rust/C#/Swift…):** оба канала — Context7 → WebSearch; экосистемный аналог `ksrc` если есть.

**High-staleness (оба канала обязательны):** Ktor 3.x, Room (KMP `@Upsert`, multiplatform), SQLDelight, kotlinx.serialization, kotlinx.datetime, Hilt, Koin, Compose Multiplatform, Compose Material3, AGP 8+/9, KSP, Firebase Android (BoM v34+ убрал KTX), Navigation 3.

## Reference implementations — реальный код как источник «как сделать»

Перед нетривиальной фичей/интеграцией искать референс-код **проактивно**, наравне с доками — это часть preparation gate ([[workflow]]), не «по запросу пользователя». Реальный текущий код часто **сильнее доков** для роли *Guides* — «как реально соединить X»: wiring/DI, конфиг-boilerplate, организация слоёв и паттернов. Для *API-truth* (сигнатуры) он остаётся supporting — `ksrc`/official = T1.

**Два класса — разный вес доверия и разный поиск:**
- **Стек-сэмплы** (под фреймворк/стек проекта), vendor-endorsed → **T1/T2**: `android/nowinandroid`, `android/compose-samples`, `android/architecture-samples`, `JetBrains/compose-multiplatform` examples, Apple `developer.apple.com/tutorials/sample-apps` / `pointfreeco/isowords`, `shadcn-ui/taxonomy`.
- **Domain-OSS** — популярное OSS-приложение **той же предметной сферы** (мессенджер при разработке мессенджера, notes при notes) → **T3**: чужой intent, может нести конвенции команды / антипаттерны. Никогда не единственный источник; cross-check с API-truth.

**Discovery (как найти правильный):** vendor-endorsed > всё остальное. Дальше — свежесть коммитов и release cadence, динамика issues, «used by», репутация мейнтейнера/организации; **не голые звёзды** (накручиваются). Domain-уровень: GitHub topics (`sample-app`, `reference-architecture`), awesome-list'ы, поиск `"{домен} app {язык} open source architecture"`.

**Guardrails (обязательны):**
- **Pointer, не embed** — ссылаться на репо/файл (`owner/repo` + путь), не копировать код в правила/контекст: иначе stale + раздувание контекста.
- **Version-proximity** — версия стека в референсе ≈ версии проекта; иначе риск deprecated path → понизить вес.
- **Usage-slice** — один репо = один способ использования, не эталон (та же оговорка, что про existing project code выше). Cross-check с T1/T2 API-truth перед переносом паттерна.

## Fast-moving declarative UI — guides & changelog before implementing

Для **Jetpack Compose, Compose Multiplatform (CMP), SwiftUI** одного «verify API against versions» мало: стек меняется быстро, и кроме *какой API есть* нужно *как сейчас рекомендуется делать* (иначе агент пишет устаревший код — `NavigationView` вместо `NavigationStack`, deprecated Compose API). Перед имплементацией нетривиального экрана/компонента в этих стеках пройти три роли — под общим принципом *Tool discovery & multi-channel use* (discover в рантайме → tier → cross-check):

**A. API-truth — какой API реально в версии проекта.** `ksrc` (T1, реальный source jar точной версии; JVM/KMP → Jetpack Compose, CMP core/Material3; не Swift) → доки того же номера / Context7 (T2). SwiftUI: `apple-doc-mcp-server` MCP когда подключён (T2; ksrc-эквивалента для Apple нет).

**B. Recommended approach — как делают сейчас** (общий принцип — см. § *Reference implementations* выше)**.** Официальные reference-приложения (код > доки, T1/T2): `android/nowinandroid`, `android/compose-samples`, `JetBrains/compose-multiplatform/examples`, Apple sample code → What's New / release-notes / roadmap (Android Dev Blog, JetBrains Kotlin Blog, WWDC) + дизайн-канон (Compose API Guidelines, Material 3, Apple HIG) → community (T3/T4, **только cross-check, не единственный источник**): Swift Forums, Hacking with Swift / Sundell / Point-Free, Kotlin Slack, Android Weekly.

**C. Что изменилось / известные проблемы.** `maven-mcp` `dependency-changes` — changelog между версиями (T2; самый богатый сигнал для CMP). Issue-трекеры **по правильному адресу**: Jetpack Compose → **Google IssueTracker** (не GitHub); CMP → GitHub issues (`JetBrains/compose-multiplatform`); SwiftUI → Apple Developer Forums / Feedback Assistant.

**Per-stack маршрут:**
- **Jetpack Compose** → `android docs` CLI + developer.android.com release-notes/BOM/roadmap + `ksrc`.
- **Compose Multiplatform** → core Compose выровнен с Jetpack Compose по **major.minor** (эмпирически: CMP 1.11.1 ↔ JC runtime 1.11.2 — minor совпадает, patch свой; CMP релизится позже календарно). **Но отдельные артефакты — Material3 и навигация (`org.jetbrains.androidx.navigation:navigation-compose`) — имеют собственную нумерацию, и KMP-форк может отставать от androidx upstream** (напр. KMP navigation 2.9.2 vs androidx 2.9.8) → версию каждого артефакта проверять отдельно (maven-mcp + CMP GitHub release-таблицы). Для общего Compose API годятся JC-доки / `android docs` / `ksrc` того же major.minor; JetBrains KMP docs / Kotlin Blog / GitHub release-таблицы — для CMP-специфики (iOS/Desktop/resources/`expect`-`actual`) и точного соответствия версий артефактов.
- **SwiftUI** → `apple-doc-mcp-server` (primary, когда подключён) + Apple/WWDC; сайт Apple — SPA, raw WebFetch ненадёжен, предпочитать MCP.
