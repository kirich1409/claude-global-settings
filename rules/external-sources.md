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

Обязательно перед Edit/Write кода, использующего внешнюю библиотеку. Тренировочные данные устаревают; existing project code показывает только используемый срез API и может быть legacy/антипаттерном. Два независимых канала с непересекающимися ролями:

| Source | Используй для | НЕ используй для |
|---|---|---|
| Existing project code | стиль, конвенции, pinned версии, какие модули подключены | API truth — сигнатуры, семантика, альтернативы |
| `ksrc` | API truth для JVM/Kotlin/KMP из реального source jar Gradle-кэша | стек без Gradle |
| `android docs search` | API truth для Jetpack/Compose/AGP/SDK | не-Android библиотеки |
| Context7 | API truth для библиотек с курируемой документацией (в основном JS/web; Kotlin покрытие неравномерное) | библиотеки без `resolve-library-id` hit |
| DeepWiki | архитектурные/поведенческие вопросы по публичным GitHub-репо | сигнатуры API |
| Memorized signatures | никогда | — |

**API-truth priority chain по стекам:**
- **JVM / Kotlin / KMP / Gradle:** `ksrc` → Context7 → DeepWiki → WebSearch
- **Android (Jetpack / Compose / AGP / SDK):** `android docs search` → `ksrc` → Context7 → DeepWiki
- **Frontend / JS / TS / web framework:** Context7 → DeepWiki → WebSearch
- **Other (Python / Go / Rust / C# / Swift / …):** Context7 → DeepWiki → WebSearch; экосистемный аналог ksrc если есть

**High-staleness libraries — всегда проверяй через API-truth канал** (training data тут чаще всего устарела): Ktor 3.x, Room (KMP `@Upsert`, multiplatform), SQLDelight, kotlinx.serialization, kotlinx.datetime, Hilt, Koin, Compose Multiplatform, Compose Material3, AGP 8+/9, KSP, Firebase Android (BoM v34+ убрал KTX), Navigation 3.

Existing project code читается **параллельно** с API-truth каналом — для стиля и pinned версий, не как замена.

Для удобной ручной инвокации workflow — `~/.claude/skills/library-verify/`.
