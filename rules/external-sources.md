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
| Reference implementations (стек-сэмплы / popular OSS) | «Как реально собрать/соединить X» — паттерны wiring/DI/boilerplate/слоёв из реального кода; см. `rules/verify-library-api.md` | API-truth (сигнатуры) — это usage-срез, не спека |

Never WebFetch rendered GitHub pages (`https://github.com/...`) — HTML noisy/expensive; use raw README.

## Tool discovery & multi-channel use

The table above names **classes of source**, not a guaranteed toolset. The actual tools reachable vary per environment: extra MCP servers, a docs/knowledge proxy, a platform-specific MCP (e.g. a Mac/desktop server behind a proxy), or additional search backends may be connected — or absent. Never assume a named tool exists, and never stop at the first one.

Single rule for every consumer (this rule, the `research` skill, the `source-researcher` agent, `write-spec` research) — gather is a three-step discipline, not a fixed pipeline:

1. **Discover** — inventory what is actually reachable now: connected MCP servers and deferred tools (via `ToolSearch`), plus built-in search/fetch. Empirically verified: a spawned subagent can both discover and invoke the session's MCP servers (incl. across servers in one turn), so a gather-agent does its own discovery — the orchestrator does not pre-bind the toolset.
2. **Use all relevant channels in parallel** — for the question's class, query **every** available channel that serves it (per the role/stack composition in `rules/verify-library-api.md`), not just one. One channel = one perspective; breadth is the point.
3. **Cross-check & tier** — verify a claim across ≥2 channels where possible and rank by *Trust assessment* (T1/T2 over T3/T4); surface disagreements and version mismatches, never silently pick one.

If a whole channel class is unavailable (no web search, no dependency-intelligence MCP, a platform MCP not connected this session), state it as an explicit limitation in the output — reduced confidence is visible, not silently degraded. A gather-agent appends the channels it actually used (and any unavailable class) to its report so the synthesizer knows what coverage backed each finding.

Library API verification, stack composition, reference implementations, and fast-moving UI guidance: see `rules/verify-library-api.md`.

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
