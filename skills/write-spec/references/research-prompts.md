Ссылается из: `~/.claude/skills/write-spec/SKILL.md` (§1.1, запуск консорциума).

> **Пересечение со скиллом `research` намеренное.** Промпты Codebase и Architecture ниже —
> обогащённое **надмножество** тех, что лежат в `../../research/references/expert-prompts.md`: здесь
> добавлены точки интеграции и тестовая инфраструктура, плюс треки, которые есть только у спеки
> (бизнес-аналитик, критическая оценка, цепочка зависимостей). Файлы держатся раздельно
> **специально** — каждый скилл самодостаточен по модели «ящик с инструментами», — так что сливать их
> в один общий не надо. Это то же самое, что идиома «тот же протокол, продублирован с пометкой» у
> пары `acceptance` ↔ `multiexpert-review`. **Исключение — веб-исследование:** оба скилла
> маршрутизируют его через одного и того же агента `source-researcher` плюс
> `~/.claude/references/external-sources.md`, поэтому метод там действительно общий, а не продублированный.
> Отдельно: трек **цепочки зависимостей**, который есть только у спеки, размечает инфраструктурные
> предусловия — API, разрешения, настройку в консолях — и это *не* трек «Dependencies» из скилла
> research про версии и CVE; он остаётся на general-purpose.

Тела промптов остаются английскими — они уходят агентам дословно.

# Шаблоны промптов исследовательских агентов

## Codebase Expert (субагент `explorer`) — включать всегда

```
Investigate the codebase for everything related to: {feature goal}

Find and report:
1. Existing code that relates to this feature — classes, interfaces, modules, files
2. Current patterns used for similar concerns in this project
3. Dependencies already in the project that are relevant
4. Module boundaries and architectural layers that would be affected
5. Integration points — where would new code connect to existing code?
6. Any TODO/FIXME comments related to this feature area
7. Test infrastructure available for the affected areas

Prefer a code-index tool for symbol resolution when one is available in the environment.
Use Grep for string literals and comments. Check build files, configuration, and test code too.

Report: overview paragraph, then findings grouped by category with file paths and
class/function names.
```

## Architecture Expert (агент architecture-expert)

Включать, когда фича добавляет новый модуль, меняет направление зависимостей, вводит новые абстракции
либо пересекает более одного архитектурного слоя.

```
Evaluate the architectural implications of: {feature goal}

Analyze:
1. Which modules and layers would be affected?
2. Does this align with the current architecture? What structural changes are needed?
3. Dependency direction — any problematic new dependencies introduced?
4. API boundaries — what contracts need to change or be created?
5. Where should new code live (which module, which layer)?
6. What existing architectural patterns should this follow?
7. Are there alternative approaches worth comparing?

Read the relevant module structure and build files before making judgments.
```

## Веб-исследование — через агента `source-researcher`

Включать, когда фича затрагивает внешние протоколы, нетривиальные алгоритмы, интеграцию со сторонним
либо незнакомый домен.

Запускать на агенте **`source-researcher`** (`focus: web`): он обнаруживает инструменты и MCP,
реально доступные в рантайме, и опрашивает каждый релевантный канал по единому методу из
`~/.claude/references/external-sources.md`, § *Что здесь есть кроме web* — правило агент наследует, здесь оно не
пересказывается. Модель и effort закреплены в агенте (`sonnet` / `medium`). Он собирает и
отчитывается без синтеза; сводит автор спеки.

```
focus: web
topic: {feature goal}
constraints: {platform and any known boundaries}

Investigate best practices and implementation approaches for this feature: common approaches
with trade-offs, known pitfalls, relevant libraries/standards, real-world open-source examples,
platform-specific considerations. Per your standing instructions: discover available channels →
query all relevant → cross-check by tier → report without synthesizing. Respond in the same
language as the feature description.
```

## Business Analyst (агент business-analyst)

Включать, когда у фичи есть влияние на пользователя, непонятный объём либо она выросла из
расплывчатой идеи.

```
Analyze the scope and requirements of: {feature goal}

Assess:
1. Is the scope well-defined? What's ambiguous?
2. What is the MVP — smallest version that delivers real value?
3. What requirements are implicit but not stated?
4. Edge cases and error scenarios not yet covered?
5. Where could this feature grow beyond its original intent?
6. Dependencies on external systems, APIs, or other teams?

Be concrete — list specific scenarios, not abstract concerns.
```

## Критическая оценка (субагент general-purpose, `model: opus`)

Включать, когда пользователь предложил конкретный технический подход либо когда в кодовой базе есть
устоявшиеся паттерны в этой области, которые могли устареть или быть проблемными.

```
Critically evaluate the approach for: {feature goal}
User's proposed approach (if any): {what the user suggested}

Investigate:
1. Existing patterns in the codebase for this concern — are they good practice or
   legacy/problematic? If problematic, explain why and what would be better.
2. Is the user's proposed approach optimal? What are its trade-offs?
3. What would a modern/industry-recommended approach look like?
4. Prepare 3 concrete approach options for the user to choose from:
   - **Radical**: most complete, modern, future-proof — higher upfront cost
   - **Classic**: follows existing project patterns — familiar but may carry baggage
   - **Conservative**: minimal change, quickest to ship — simplest but most limited
5. For each option: trade-offs, estimated complexity, recommended when.

Do NOT recommend blindly following project patterns if they are outdated or problematic.
Flag bad patterns explicitly — the user should know before committing to them.
```

## Цепочка зависимостей (субагент general-purpose, `model: sonnet`)

Включать, когда фича интегрируется с внешними сервисами, требует возможностей уровня ОС, трогает
инфраструктуру либо запрос пользователя подразумевает фазу настройки.

```
Map the full dependency chain for: {feature goal}

Identify everything that must exist or be configured BEFORE the feature can work:

1. Infrastructure / services — third-party APIs, cloud services, databases, queues
2. Platform requirements — OS permissions, capability declarations, entitlements
3. Console / dashboard setup — developer consoles, API keys, service accounts
4. Configuration — environment variables, config files, secrets
5. Code prerequisites — base classes, interfaces, or modules that must exist first
6. Test prerequisites — what test infrastructure or fixtures are needed

For each dependency: is it already in place, or does it need to be created/configured?
Flag any dependency that requires manual steps outside of code (e.g., "create FCM project
in Firebase console") — these become explicit prerequisite steps in the spec.
```
