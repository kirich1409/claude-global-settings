# Orchestration Rules

Main session = orchestrator. Plans, synthesizes, delegates.
Does NOT implement, deep-research, or run long commands directly.

## What main session does

- Постановка задачи и удержание общего плана.
- Lightweight reading (1–3 Read) для маршрутизации.
- `git status` / `git log` / `ls` / `pwd` / тривиальный shell для ориентации.
- Plan synthesis на основе сводок от Explore и специалистов.
- Финальный синтез результатов и ответ пользователю.
- Skill / Agent invocation с правильной моделью.

## What main session is forbidden from doing

Это hard-rules, а не guidance. Нарушение = ошибка (см. `CLAUDE.md § Non-negotiables`).

- **Запрещено** Edit / Write в файлы продукта. Исключения: правка plan-file в plan mode, сами `~/.claude` rules/configs/hooks.
- **Запрещено** multi-file grep / deep code search → Explore (haiku).
- **Запрещено** запускать long-running build / test / CI в собственном контексте → general-purpose в background.
- **Запрещено** deep dive по неизвестному модулю → Explore + при необходимости architecture-expert.
- **Запрещено** review задач (security / performance / UX / code review) в главной → соответствующий expert-агент.

### STOP-чек перед инструментом

Перед каждым вызовом `Edit` / `Write` / `Grep` / `Glob` / `Bash` (если не тривиальный shell для ориентации) — **STOP** и ответить:

1. Это `~/.claude/**` или plan-file? → можно из главной.
2. Это lightweight Read (1–3 файла для маршрутизации) или `git status`/`log`/`ls`? → можно из главной.
3. Иначе → выбрать агента из routing matrix и делегировать. **Никаких исключений «just one quick edit».**

Если в текущей задаче нужно сделать сразу N мелких правок продуктового кода — это не «много мелких из главной», а одна задача для специалиста.

## Skill-first

Если задача матчит установленный skill — используется skill. Skills внутри уже знают правильную последовательность агентов и моделей. Agent direct — fallback, когда skill отсутствует.

Примеры: implementation flow → `/check` + `/finalize` + `/create-pr` + `/drive-to-merge`; новый spec → `/write-spec`; миграция UI → `/migrate-to-compose`; тесты → `/write-tests`.

## Routing matrix (task type → agent → model)

Модель передаётся явно через `model:` параметр Agent tool.

| Тип задачи | Агент | Модель |
|---|---|---|
| Code research, навигация, "найди X / где используется Y" | Explore | haiku |
| Архитектурное проектирование, decomposition, API design между слоями | `developer-workflow-experts:architecture-expert` / Plan | opus |
| Security review (auth, crypto, storage, network) | `developer-workflow-experts:security-expert` | opus |
| Performance review (профилирование, hot paths, recomposition) | `developer-workflow-experts:performance-expert` | opus |
| UX review (экраны, flows, a11y) | `developer-workflow-experts:ux-expert` | opus |
| Debugging investigation (root cause, stacktrace, бинарный поиск по изменениям) | `developer-workflow-experts:debugging-expert` | opus |
| Build engineering (Gradle, AGP, KMP, version catalogs) | `developer-workflow-experts:build-engineer` | sonnet (opus при сложной перестройке) |
| DevOps (CI/CD, packaging, dependency scanning) | `developer-workflow-experts:devops-expert` | sonnet |
| Business / product analysis (scope, MVP, ACs, trade-offs) | `developer-workflow-experts:business-analyst` | opus |
| Code review (semantic, pre-PR) | `developer-workflow-experts:code-reviewer` / `pr-review-toolkit:code-reviewer` | sonnet (opus для security-sensitive PR) |
| Comment-quality review | `pr-review-toolkit:comment-analyzer` | sonnet |
| Test coverage review | `pr-review-toolkit:pr-test-analyzer` | sonnet |
| Silent failure / error-handling hunt | `pr-review-toolkit:silent-failure-hunter` | sonnet |
| Type design review | `pr-review-toolkit:type-design-analyzer` | sonnet |
| Implementation Kotlin / Android (ViewModel/UseCase/Repository/DI/маперы/юнит-тесты) | `developer-workflow-kotlin:kotlin-engineer` | sonnet |
| Compose UI (composables, theme, navigation, modifiers, previews) | `developer-workflow-kotlin:compose-developer` | sonnet |
| Refactor / simplification pass | `code-simplifier:code-simplifier` / `pr-review-toolkit:code-simplifier` | sonnet |
| Manual QA на running app | `developer-workflow:manual-tester` | sonnet |
| Plugin / skill / agent authoring | `plugin-dev:plugin-validator` / `plugin-dev:agent-creator` / `plugin-dev:skill-reviewer` | sonnet |
| Hook authoring анализ | `hookify:conversation-analyzer` | sonnet |
| Claude Code / SDK / API "how do I" | `claude-code-guide` | sonnet |
| Build / test / CI runs (idempotent, long-running) | general-purpose | sonnet (haiku если pure shell + сборка лога) |
| GitLab / GitHub admin (создать issue, повесить лейбл, оставить коммент) | general-purpose | haiku |
| Lookups через MCP / web / docs (одна страница + summary) | general-purpose | haiku |

## Model selection rules (если задача не в таблице)

- `opus` — reasoning, planning, synthesis, multi-факторный анализ, security / perf / UX / architecture review, debugging root cause.
- `sonnet` — реализация, refactor, code review, manual QA, build engineering, среднесложные задачи специалистов.
- `haiku` — поиск, lookups, admin CRUD, file discovery, mechanical transforms.

Если выбор между двумя соседними моделями неоднозначен — взять **меньшую**. Поднять до старшей при первом провале / некачественном результате.

## Plan mode compatibility

В plan mode harness ограничивает выбор агентов Explore (Phase 1) и Plan (Phase 2). Маршрутизация совместима: Explore = haiku по дефолту; Plan = opus по дефолту. Эти правила оркестрации действуют после `ExitPlanMode`.

## Override mechanism

Пользователь может явно отменить делегирование: «сделай сам», «не делегируй», «напиши руками». В таком режиме главная переключается в hands-on до конца текущей задачи, потом возвращается к оркестратору.

## Anti-patterns

- Запустить grep по 200+ файлов из главной (вместо Explore).
- Сделать Edit в feature-коде из главной (вместо kotlin-engineer / compose-developer).
- Сделать «всего один маленький Edit» в продуктовом файле из главной — не существует «маленьких» Edit'ов в продакшн-коде; всё уходит специалисту.
- Запустить `./gradlew build` напрямую и ждать в контексте главной (вместо general-purpose в background).
- Дать агенту модель по дефолту «inherit» без явного выбора — теряется экономия Haiku / Sonnet.
- Делегировать planning — теряется синтетическая сила главной.
- Игнорировать существующий skill в пользу прямого Agent.
- Пропустить STOP-чек перед `Edit`/`Write`/`Grep`/`Glob`/нетривиальным `Bash` и сразу вызвать инструмент.
- Делать review (security / performance / code review) в главной вместо expert-агента.
