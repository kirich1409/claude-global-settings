# External Sources

## Source routing

| Source | Use for | Don't use for |
|---|---|---|
| Local code / project files | First stop for project questions | — |
| `ksrc` | Reading JVM/Gradle dep sources (real source jar) | Project-internal code |
| `android docs search`/`fetch` | API truth + guides for Android/Jetpack/Compose/AGP/SDK (curated developer.android.com) | non-Android libs |
| `~/.android/cli/skills/**/SKILL.md` | Bundled Android CLI skills — structured workflows (migrations; узкие области: Wear/XR/edge-to-edge/Compose styles/R8/Perfetto…). Discovery: `android skills find <kw>` → Read the SKILL.md. См. `rules/android-cli.md` | API truth для библиотек; не-Android задачи |
| Context7 | Published library/framework docs, current API/migration | Project code, debugging own code; one `resolve-library-id` fail → stop, don't chase synonyms |
| `WebSearch`/`WebFetch` | Default for everything not covered above | — |
| Raw README via `raw.githubusercontent.com` | Last-resort for a specific repo | — |

Never WebFetch rendered GitHub pages (`https://github.com/...`) — HTML noisy/expensive; use raw README.

## Tool discovery & multi-channel use

The table above names **classes of source**, not a guaranteed toolset. The actual tools reachable vary per environment: extra MCP servers, a docs/knowledge proxy, a platform-specific MCP (e.g. a Mac/desktop server behind a proxy), or additional search backends may be connected — or absent. Never assume a named tool exists, and never stop at the first one.

Single rule for every consumer (this rule, the `research` skill, the `source-researcher` agent, `write-spec` research) — gather is a three-step discipline, not a fixed pipeline:

1. **Discover** — inventory what is actually reachable now: connected MCP servers and deferred tools (via `ToolSearch`), plus built-in search/fetch. Empirically verified: a spawned subagent can both discover and invoke the session's MCP servers (incl. across servers in one turn), so a gather-agent does its own discovery — the orchestrator does not pre-bind the toolset.
2. **Use all relevant channels in parallel** — for the question's class, query **every** available channel that serves it (per the role/stack composition in *Verify library API before code* below), not just one. One channel = one perspective; breadth is the point.
3. **Cross-check & tier** — verify a claim across ≥2 channels where possible and rank by *Trust assessment* (T1/T2 over T3/T4); surface disagreements and version mismatches, never silently pick one.

If a whole channel class is unavailable (no web search, no dependency-intelligence MCP, a platform MCP not connected this session), state it as an explicit limitation in the output — reduced confidence is visible, not silently degraded. A gather-agent appends the channels it actually used (and any unavailable class) to its report so the synthesizer knows what coverage backed each finding.

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

## Fast-moving declarative UI — guides & changelog before implementing

Для **Jetpack Compose, Compose Multiplatform (CMP), SwiftUI** одного «verify API against versions» мало: стек меняется быстро, и кроме *какой API есть* нужно *как сейчас рекомендуется делать* (иначе агент пишет устаревший код — `NavigationView` вместо `NavigationStack`, deprecated Compose API). Перед имплементацией нетривиального экрана/компонента в этих стеках пройти три роли — под общим принципом *Tool discovery & multi-channel use* (discover в рантайме → tier → cross-check):

**A. API-truth — какой API реально в версии проекта.** `ksrc` (T1, реальный source jar точной версии; JVM/KMP → Jetpack Compose, CMP core/Material3; не Swift) → доки того же номера / Context7 (T2). SwiftUI: `apple-doc-mcp-server` MCP когда подключён (T2; ksrc-эквивалента для Apple нет).

**B. Recommended approach — как делают сейчас.** Официальные reference-приложения (код > доки, T1/T2): `android/nowinandroid`, `android/compose-samples`, `JetBrains/compose-multiplatform/examples`, Apple sample code → What's New / release-notes / roadmap (Android Dev Blog, JetBrains Kotlin Blog, WWDC) + дизайн-канон (Compose API Guidelines, Material 3, Apple HIG) → community (T3/T4, **только cross-check, не единственный источник**): Swift Forums, Hacking with Swift / Sundell / Point-Free, Kotlin Slack, Android Weekly.

**C. Что изменилось / известные проблемы.** `maven-mcp` `dependency-changes` — changelog между версиями (T2; самый богатый сигнал для CMP). Issue-трекеры **по правильному адресу**: Jetpack Compose → **Google IssueTracker** (не GitHub); CMP → GitHub issues (`JetBrains/compose-multiplatform`); SwiftUI → Apple Developer Forums / Feedback Assistant.

**Per-stack маршрут:**
- **Jetpack Compose** → `android docs` CLI + developer.android.com release-notes/BOM/roadmap + `ksrc`.
- **Compose Multiplatform** → core Compose выровнен с Jetpack Compose по **major.minor** (эмпирически: CMP 1.11.1 ↔ JC runtime 1.11.2 — minor совпадает, patch свой; CMP релизится позже календарно). **Но отдельные артефакты — Material3 и навигация (`org.jetbrains.androidx.navigation:navigation-compose`) — имеют собственную нумерацию, и KMP-форк может отставать от androidx upstream** (напр. KMP navigation 2.9.2 vs androidx 2.9.8) → версию каждого артефакта проверять отдельно (maven-mcp + CMP GitHub release-таблицы). Для общего Compose API годятся JC-доки / `android docs` / `ksrc` того же major.minor; JetBrains KMP docs / Kotlin Blog / GitHub release-таблицы — для CMP-специфики (iOS/Desktop/resources/`expect`-`actual`) и точного соответствия версий артефактов.
- **SwiftUI** → `apple-doc-mcp-server` (primary, когда подключён) + Apple/WWDC; сайт Apple — SPA, raw WebFetch ненадёжен, предпочитать MCP.

## Context7 workflow

Шаги при обращении к Context7 (когда именно — см. таблицу Source routing и композицию по стекам выше):

1. Начни с `resolve-library-id` по имени библиотеки + вопросу пользователя — кроме случая, когда дан точный ID в формате `/org/project`.
2. Выбери лучшее совпадение (ID `/org/project`) по: точному совпадению имени, релевантности описания, числу code-сниппетов, репутации источника (High/Medium), benchmark score (выше — лучше). Не туда — переформулируй (`next.js`, не `nextjs`) или используй версионный ID, если указана версия.
3. `query-docs` с выбранным ID и полным вопросом пользователя (не одним словом).
4. Отвечай по полученной docs.

Один провал `resolve-library-id` → стоп, не гнаться за синонимами. Не использовать для: рефакторинга, написания скриптов с нуля, отладки бизнес-логики, code review, общих концепций программирования.

## Trust assessment

Источник может быть формально primary, а content — устаревший / для другой версии / AI-галлюцинация. Оцени tier до того, как поверить.

| Tier | Что | Источники |
|---|---|---|
| **T1** ground truth | артефакт без интерпретации | `ksrc`, existing project code, official release artifact |
| **T2** official docs | курируемая вендорская docs, releases/changelogs | `android docs`, Context7 для официальных либ, vendor changelog |
| **T3** aggregated/AI | может галлюцинировать | Context7 для community либ без вендорской docs |
| **T4** random web | блоги, StackOverflow, Medium, tutorials | WebSearch, случайный WebFetch |

**Память — не tier.** Авто-память (`MEMORY.md`, recalled facts) и существующий код проекта фиксируют то, что было верно на момент записи, и устаревают — это **не** источник знания об API/версиях/поведении. При пробеле или сомнении перепроверь по T1/T2 (официальный источник), не действуй по памяти. Память годится как указатель «где смотреть», не как факт.

**Default: T1 + T2 параллельно** для любого Edit/Write с внешней библиотекой — базовый режим, не «при сомнении». T1-only допустим **только** с явным обоснованием в reasoning: стабильная Java/Kotlin stdlib (не evolving либа); уже виденный символ на той же pinned версии, `ksrc` подтверждает форму, локальный helper / data class без поведения; тривиальное использование (конструктор data class, enum value, константа). «Кажется очевидным» — не обоснование.

**Валидация перед использованием:**
- Версия источника = версии в проекте? Нет → флаг, не использовать без cross-check, отметить в reasoning (T1 = pinned, T2 = current; расхождение = проект отстал или docs про другую major).
- T3/T4 старше года в evolving стеке (Compose/Ktor/AGP/KMP/Hilt/kotlinx.*) — подозрительно, понизить вес.
- T3 aggregated/AI — никогда единственный источник для сигнатур/версий; только в паре с T1 или T2.
- Red flags (понизить tier на 1): источник не указывает версию; сигнатура не воспроизводится в `ksrc`; текст «выглядит сгенерированным» (общие фразы, размытые типы); tutorial/блог без даты.

**Конфликты:**
- **T1 vs T2** — следовать T1 (реально доступно в проекте), отметить расхождение пользователю; при существенном gap — предложить bump через plan-stage gate.
- **T1/T2 vs T3/T4** — T1/T2 выигрывают безусловно.
- **T2 vs T2** (два официальных расходятся) — свежий вендорский changelog > старая docs-страница; непонятно → поднять вопрос, не выбирать молча.
