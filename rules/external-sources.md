# External Sources

## Source routing

| Source | Use for | Don't use for |
|---|---|---|
| Local code / project files | First stop for project questions | — |
| `ksrc` | Reading JVM/Gradle dep sources | Project-internal code |
| DeepWiki | Specific *public* GitHub repo, arch/behavior/docs level | Current project, non-GitHub, general concepts. Verify the repo is on public GitHub before trying. |
| Context7 | Published library/framework docs (React, Spring, Ktor…), current API/migration | Project code, debugging your own code, libraries you haven't `resolve-library-id`'d (one fail → stop, don't chase synonyms) |
| `WebSearch` / `WebFetch` | Default for everything else not covered above | — |
| Raw README via `raw.githubusercontent.com` | Last-resort for a specific repo | — |
| Perplexity MCP | Only when user explicitly asks ("через perplexity") or research stage in dev-workflow | Default web research |

Never fetch rendered GitHub pages (`https://github.com/...`) with WebFetch — HTML is noisy and expensive.

## Verify library API before code

Обязательно перед Edit/Write кода, использующего внешнюю библиотеку. Тренировочные данные устаревают; existing project code показывает только используемый срез API и может быть legacy/антипаттерном.

### Три роли источников — каналы дополняют, а не исключают друг друга

У источников разные роли. На одну задачу часто нужно запустить **несколько каналов параллельно**, а не выбирать «один из». Цепочка «→» ниже — это fallback внутри одной роли (если первый источник не дал ответа), а не приоритет между ролями.

| Роль | Что даёт | Когда нужна |
|---|---|---|
| **API truth** | сигнатуры, семантика, типы, альтернативы | всегда, когда пишется/правится код с этой библиотекой |
| **Guides & recommended approaches** | рекомендуемые паттерны, migration guides, training, codelabs, troubleshooting, «как принято» | задачи вида «как сделать X», «какой подход», «migration с A на B», незнакомая часть стека, не-тривиальная интеграция |
| **Project style & versions** | стиль, конвенции, pinned версии, какие модули уже подключены | всегда — параллельно с внешними каналами |

| Источник | API truth | Guides | Project style | Особенности |
|---|---|---|---|---|
| Existing project code | — | — | ✓ primary | стиль и pinned версии, **не** API truth |
| `ksrc` | ✓ primary для JVM/Kotlin/KMP | — | — | реальный source jar из Gradle-кэша, без интерпретации |
| `android docs search` / `fetch` | ✓ primary для Android/Jetpack/Compose/AGP/SDK | ✓ **primary для Android** — training, guide, codelabs, migration notes | — | курируемый developer.android.com, без HTML-шума |
| Context7 | ✓ для библиотек с курируемой docs (в основном JS/web; Kotlin неравномерно) | ✓ когда у библиотеки есть guides секция | — | требует успешный `resolve-library-id`; один промах → не подбирать синонимы |
| DeepWiki | частично — архитектурные вопросы | ✓ для публичных GitHub-репо | — | не для точных сигнатур; только публичные GitHub |
| WebSearch / WebFetch | last-resort | last-resort | — | никогда на рендеренные github.com страницы |
| Memorized signatures | никогда | никогда | — | — |

### Композиция каналов по стекам

Для каждой задачи — **запускай оба канала параллельно** (API truth + Guides, если задача нетривиальна). Existing project code читается всегда поверх — отдельным проходом, не как замена внешних источников.

**Android (Jetpack / Compose / AGP / SDK / Play / KTX):**
- API truth: `ksrc` + `android docs search` — параллельно. `ksrc` показывает реальный API из jar, `android docs` подтверждает текущую рекомендованную форму. Не «или/или».
- Guides: `android docs search` — primary. Триггер: «как», «какой подход», «migration», «best practice», незнакомый компонент.
- Fallback (только если оба молчат): Context7 → DeepWiki → WebSearch.

**JVM / Kotlin / KMP / Gradle (не-Android):**
- API truth: `ksrc` primary. Fallback: Context7 → DeepWiki → WebSearch.
- Guides: Context7 (если у библиотеки есть guides секция) → DeepWiki → WebSearch.
- Для Kotlin/JVM `ksrc` даёт только сорсы — для «как принято» всё равно нужен второй канал.

**Frontend / JS / TS / web framework:**
- API truth: Context7 primary → DeepWiki → WebSearch.
- Guides: Context7 → DeepWiki → WebSearch.

**Other (Python / Go / Rust / C# / Swift / …):**
- API truth: Context7 → DeepWiki → WebSearch; экосистемный аналог `ksrc` если есть.
- Guides: Context7 → DeepWiki → WebSearch.

### High-staleness libraries

Training data устарела чаще всего здесь — оба канала (API truth + guides) обязательны: Ktor 3.x, Room (KMP `@Upsert`, multiplatform), SQLDelight, kotlinx.serialization, kotlinx.datetime, Hilt, Koin, Compose Multiplatform, Compose Material3, AGP 8+/9, KSP, Firebase Android (BoM v34+ убрал KTX), Navigation 3.

Для удобной ручной инвокации workflow — `~/.claude/skills/library-verify/`.
