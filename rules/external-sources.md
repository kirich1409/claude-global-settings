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

## Verify library API before code

Обязательно перед Edit/Write кода с внешней библиотекой. Training data устаревает; existing project code = только используемый срез API, может быть legacy/антипаттерном.

**Три роли каналов — дополняют, не исключают; часто нужны параллельно:**
- **API truth** (сигнатуры, семантика, типы, альтернативы) — всегда при написании/правке кода с библиотекой.
- **Guides** (рекомендуемые паттерны, migration, codelabs, troubleshooting, «как принято») — для «как сделать X», «миграция A→B», незнакомого стека, нетривиальной интеграции.
- **Project style & versions** (стиль, pinned версии, подключённые модули) — всегда, отдельным проходом поверх внешних каналов; это **не** API truth.

`→` ниже = fallback внутри одной роли, **не** приоритет между ролями. Memorized signatures — **никогда** как источник.

**Композиция по стекам** (API truth + Guides — параллельно, если задача нетривиальна):
- **Android:** API truth = `ksrc` + `android docs` параллельно (jar + текущая рекомендация, не «или/или»). Guides = `android docs` + bundled Android CLI skills параллельно (skills = structured workflows для миграций/областей; docs = точечные guides/codelabs). Fallback: Context7 → DeepWiki → WebSearch.
- **JVM/Kotlin/KMP/Gradle (не-Android):** API truth = `ksrc` primary → Context7 → WebSearch. Guides = Context7 (Kotlin покрыт неравномерно) → WebSearch. `ksrc` даёт только сорсы — для «как принято» нужен второй канал.
- **Frontend/JS/TS:** оба канала — Context7 primary → WebSearch.
- **Other (Python/Go/Rust/C#/Swift…):** оба канала — Context7 → WebSearch; экосистемный аналог `ksrc` если есть.

**High-staleness (оба канала обязательны):** Ktor 3.x, Room (KMP `@Upsert`, multiplatform), SQLDelight, kotlinx.serialization, kotlinx.datetime, Hilt, Koin, Compose Multiplatform, Compose Material3, AGP 8+/9, KSP, Firebase Android (BoM v34+ убрал KTX), Navigation 3.

## Trust assessment

Источник может быть формально primary, а content — устаревший / для другой версии / AI-галлюцинация. Оцени tier до того, как поверить.

| Tier | Что | Источники |
|---|---|---|
| **T1** ground truth | артефакт без интерпретации | `ksrc`, existing project code, official release artifact |
| **T2** official docs | курируемая вендорская docs, releases/changelogs | `android docs`, Context7 для официальных либ, vendor changelog |
| **T3** aggregated/AI | может галлюцинировать | Context7 для community либ без вендорской docs |
| **T4** random web | блоги, StackOverflow, Medium, tutorials | WebSearch, случайный WebFetch |

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
