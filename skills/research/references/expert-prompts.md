# Research Consortium — шаблоны промптов экспертов

Механика запусков — SKILL.md, фаза 2, § «Как ведут себя запуски»: здесь она не пересказывается.
Каждый агент работает независимо; находки одного другому не передаются никогда. Два трека, **привязанных к кодовой базе** (Codebase,
Architecture), используют дословные промпты ниже на `Explore` и `architecture-expert`; четыре
**внешних** трека (Web, Docs, Dependencies, OSS Examples) работают на агенте `source-researcher`
(см. раздел про внешние треки).

> **Пересечение с `write-spec` намеренное.** Промпты Codebase и Architecture здесь пересекаются с
> `../../write-spec/references/research-prompts.md`, где они выглядят обогащённым надмножеством. Файлы
> держатся раздельно **специально**, чтобы каждый скилл оставался самодостаточным, — сливать их в
> общий не надо. Сбор внешних источников оба скилла маршрутизируют через одного и того же агента
> `source-researcher` плюс `~/.claude/references/external-sources.md`, так что *метод* как раз общий; дублируются
> намеренно только промпты по кодовой базе.

Каждый промпт обязан содержать строку: *«Respond in the same language as the research topic
description.»*

## Блок акцентов

Акценты, собранные конфигурационным раундом фазы 1.5 и аргументом `--focus`, вставляются **в каждый**
запускаемый промпт одинаковым блоком — тем же текстом, без подгонки под трек:

```
Focus areas (prioritise, do not filter): {акцент 1; акцент 2; …}
```

Одинаковость обязательна: разные акценты разным трекам — это оркестратор, который уже знает ответ и
подталкивает к нему сборщиков, то есть та самая утечка между изолированными агентами, против которой
устроен консорциум. Акцентов не задавали — блок опускается целиком, заглушку не вставлять.

Слово «prioritise, do not filter» в строке не декоративное: находка вне акцентов остаётся в отчёте
эксперта, акценты задают лишь порядок внимания и глубину копания.

Строка `Seed repositories` — исключение из требования одинаковости: она адресует конкретную работу
одного трека, а не расставляет приоритеты всем. Её получает **только** экземпляр с
`focus: oss-examples`; выдать её остальным значит сообщить им заготовку ответа. «Start here, do not
stop here» так же не декоративно: трек обязан искать за пределами списка и по каждому пиннированному
репозиторию сказать, подтвердилось ожидание или нет.

---

## Обнаружение инструментов и работа по нескольким каналам — единый источник

Метод обнаружения доступных инструментов и MCP, опроса **всех** релевантных каналов класса и
перекрёстной проверки по tier доверия здесь **не дублируется**. Он лежит в одном месте:
`~/.claude/references/external-sources.md`, § *Что здесь есть кроме web*, плюс `~/.claude/references/verify-library-api.md` про
состав стека и § *Оценка доверия* про tier.

Кто из участников до этого метода дотягивается — важно, потому что каналы наследования разные:
`source-researcher` знает путь из собственного системного промпта, `architecture-expert` наследует
безусловные правила. **`Explore` не наследует ничего** — по `~/.claude/rules/orchestration.md` он
пропускает `CLAUDE.md`, rules и `MEMORY.md` целиком, а `references/**` не загружается ни у кого. Всё,
что нужно треку Codebase, обязано стоять в его дословном промпте.

Четыре **внешних** трека не получают зашитого инструмента в промпте: они идут на агенте
**`source-researcher`**, который обнаруживает каналы сам в рантайме. Два трека, привязанных к кодовой
базе, сохраняют собственные промпты — у `Explore` и `architecture-expert` разные задачи и
инструментарий.

---

## Внешние треки — запуск через агента `source-researcher`

Web, Docs, Dependencies и OSS Examples — четыре **независимых** экземпляра `source-researcher`, каждый
со своим `focus`. Независимость экземпляров и сохраняет инвариант против синтетического смещения:
схлопывать их в один вызов нельзя. Агент уже знает свой метод и структуру отчёта, поэтому промпт
запуска задаёт только focus, тему и ограничения. Модель и effort берутся из определения агента — не
переопределять и не дублировать здесь значениями, которые разойдутся с его frontmatter при первой же
правке.

Каждый выбранный внешний трек запускать с `agentType: source-researcher` и таким промптом:

```
focus: {web | library-docs | dependency-intelligence | oss-examples}
topic: {тема}
constraints: {известные границы — только KMP, без новых зависимостей, закреплённые версии, срок}
Focus areas (prioritise, do not filter): {акценты фазы 1.5 и --focus; строка опускается, если их нет}
Report budget: claim + locator per finding; verbatim quote only for a signature, a version string or
a changelog line, and never longer than two lines.
Seed repositories (start here, do not stop here): {owner/repo, … — ТОЛЬКО для focus: oss-examples,
из фазы 1.6; строка опускается, если репозиториев нет}

Investigate only your focus class for this topic, per your standing instructions
(discover available channels → query all relevant ones → cross-check by tier → report
without synthesizing). Respond in the same language as the topic description.
```

Соответствие трека и focus:

| Трек | `focus` | Что покрывает |
|---|---|---|
| Web | `web` | индустриальная практика, компромиссы, подводные камни, события за последние ≤12 месяцев, консенсус — из статей и обсуждений, то есть *дискурс* о подходе, а не код |
| Docs | `library-docs` | справочник API, руководства, changelog, миграции и совместимость, поведение конкретных версий |
| Dependencies | `dependency-intelligence` | текущие и последние версии, CVE, совместимость, здоровье проекта, ломающие изменения, альтернативы |
| OSS Examples | `oss-examples` | реальные использования в открытом коде, свидетельства реализуемости («существует ли рабочий пример?»), актуальные паттерны связывания и интеграции — указатели на репозиторий, файл и версию, а не вставленный код. Каталог каналов: `~/.claude/references/external-sources.md`, § *Что здесь есть кроме web* |

Подробные углы по классам, раньше лежавшие здесь, теперь живут в системном промпте агента
(`agents/source-researcher.md`) и в `external-sources.md` — единый источник, без пересказов.

---

## Codebase Expert (субагент Explore)

Директива про индекс кода стоит в промпте дословно, а не подразумевается: `Explore` правил не видит,
и без неё он уходит грепом по всей кодовой базе — самым дорогим способом сделать ровно то, для чего
индекс и существует.

```
Investigate the codebase for everything related to: {topic}

Find and report:
1. Existing code that relates to this topic (classes, interfaces, modules)
2. Current patterns and approaches used for similar concerns
3. Dependencies already in the project that are relevant
4. Module boundaries and layers that would be affected
5. Any existing TODO/FIXME comments related to this topic

Use `ast-index` via Bash before Grep: `search "q"`, `file "Name"`, `class "Name"`,
`usages "Name"`, `implementations "Name"`, `callers "fn"`. Grep only when ast-index is
empty or for regex/string-literal search. Before `Read` on a file >~500 lines, run
`ast-index outline <file>` and Read only the targeted slice via `offset`/`limit`.
On "Index not found" → `ast-index rebuild`, never fall back to Grep.
Check build files, configuration, and test code too.

Focus areas (prioritise, do not filter): {акценты фазы 1.5 и --focus; строка опускается, если их нет}

Respond in the same language as the research topic description. Structure: overview,
then findings grouped by category.
```

---

## Architecture Expert (агент architecture-expert)

```
Evaluate the architectural implications of: {topic}

Analyze:
1. Which modules and layers would be affected?
2. Does this align with the current architecture, or does it require structural changes?
3. Dependency direction — would this introduce any problematic dependencies?
4. API boundaries — what contracts need to change or be created?
5. Integration points — where does this touch existing abstractions?

Read the relevant module structure and build files before making judgments.

Focus areas (prioritise, do not filter): {акценты фазы 1.5 и --focus; строка опускается, если их нет}

Respond in the same language as the research topic description.
```

---

## Auto-review — агент `business-analyst` (фаза 4)

Запустить агента `business-analyst` против синтезированного отчёта. Его взгляд отличается от взгляда
сборщиков: он проверяет полноту, продуктовый смысл и практическую жизнеспособность.

```
Отревьюй этот research-отчёт на полноту и практическую жизнеспособность.

{полный отчёт}

Проверь:
1. Все ли подходы оценены с компромиссами?
2. Не упущены ли очевидные альтернативы?
3. Покрывают ли риски и технические, и продуктовые аспекты?
4. Подкреплена ли рекомендация доказательствами?
5. Содержит ли раздел «Known Unknowns» ТОЛЬКО внешние фактические пробелы, которые никто из
   участников сессии не может закрыть сейчас (SLA вендора, непубличная цена, будущая дата GA), —
   и НИ ОДНОГО вопроса пользователю, ни одной заглушки «TBD», ни одного риторического вопроса?
   Компромиссы, разрешаемые пользователем, в этом разделе быть не должно — назови их отдельно,
   они уходят в раунд уточнений, который идёт после твоего ревью.
6. Согласуется ли рекомендация с практическими ограничениями — время, навыки команды, поддержка?
7. Если отчёт помечен `Mode: autonomous` — назван ли в «Assumptions» каждый выбор, сделанный за
   пользователя, вместе с фактом, который его перевернёт? Допущение, растворённое в тексте
   рекомендации и не вынесенное в раздел, считается пробелом severity major.

Перечисли пробелы с severity (critical / major / minor).
Отвечай на языке описания темы.
```
