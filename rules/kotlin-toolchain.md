# Kotlin Toolchain Rules

JetBrains' **Kotlin Toolchain** (https://kotlin-toolchain.org/latest/) — agent-friendly declarative build tool for Kotlin / KMP / Compose Multiplatform projects. Project descriptor — `module.yaml`; CLI binary — `kotlin`; IntelliJ IDEA plugin требует версию 2026.1.2 или новее.

**Status:** Alpha (v0.11.x по состоянию на 2026-05). API и CLI могут меняться между релизами. Не рекомендовать Kotlin Toolchain как build-систему для production-проекта без явного surfacing Alpha-статуса пользователю. Документация на kotlin-toolchain.org остаётся authoritative для **текущего** синтаксиса.

Правила протестированы против `kotlin` CLI v0.11.x.

## Scope

Applies when **any** of the following hold:
- В корне проекта присутствует `module.yaml`.
- Вопрос пользователя про Kotlin Toolchain CLI (`kotlin build|test|run|...`), схему `module.yaml`, миграцию с Gradle на Toolchain, Compose Multiplatform setup через Toolchain.
- Пользователь явно упоминает «Kotlin Toolchain» или даёт ссылку на `kotlin-toolchain.org`.

Для Gradle-only Kotlin-проектов (нет `module.yaml`) это правило **молчит** — Gradle и существующие цепочки из `rules/external-sources.md` применяются как есть.

## Availability check

На первом релевантном вызове в сессии:

1. `command -v kotlin` — если бинарника нет → fallback на docs-only (см. секцию Fallback).
2. **Disambiguate Toolchain CLI от legacy `kotlin` (REPL / `*.kts` runner) из Kotlin SDK.** Запустить `kotlin --help | head -40`. Подтверждение Toolchain — в выводе присутствуют subcommands `build`, `publish`, `update` (или явное упоминание «Kotlin Toolchain»). Если вывод выглядит как REPL (`-script`, `-e <expr>`, `-version` без subcommands) → бинарник — legacy SDK, для Toolchain недоступен.
3. Закешировать результат на сессию. **Не перепроверять** при последующих вызовах.

Если disambiguation провалился — один раз уведомить пользователя: «`kotlin` указывает на REPL/scripting CLI, не на Kotlin Toolchain. Установить Toolchain — https://kotlin-toolchain.org/latest/getting-started/». Дальше работать только через docs fallback.

## Decision matrix (CLI available, Toolchain confirmed)

| Task | Command |
|------|---------|
| Compile + link всего проекта | `kotlin build` |
| Прогнать тесты | `kotlin test` |
| Прогнать checks (lint / static analysis pipeline) | `kotlin check` |
| Удалить build output / project cache | `kotlin clean` |
| Удалить shared cache между проектами | `kotlin clean-shared-caches` |
| Запустить приложение | `kotlin run` |
| Упаковать артефакты для distribution | `kotlin package` |
| Показать инфо о проекте (modules, tasks, effective settings) | `kotlin show <topic>` |
| Запустить конкретный task из task graph | `kotlin task <name>` |
| Запустить зарегистрированный tool | `kotlin tool <name>` |
| Выполнить custom command, объявленную в проекте | `kotlin do <name>` |
| Сгенерировать tab-completion | `kotlin generate-completion (bash\|zsh\|fish)` |
| Verbose logging для диагностики | `kotlin --log-level=debug <cmd>` |

### Docs / reference

| Task | Method |
|------|--------|
| Прочитать схему `module.yaml`, концепции Toolchain, Compose MP setup, migration с Gradle | `WebFetch https://kotlin-toolchain.org/latest/<page>` (домен в WebFetch allow-list) |
| Индексировать docs для последующего поиска | `ctx_fetch_and_index` через context-mode flow, когда нужно extensive чтение |

## Priority versus existing tools

- **Build / test / run / check / package:**
  - `module.yaml` present + Toolchain CLI подтверждён → `kotlin <cmd>` — **primary**.
  - Только `build.gradle*`, нет `module.yaml` → Gradle (`./gradlew <task>`) primary; это правило молчит.
  - Присутствуют **оба** маркера (миграционная фаза) → **спросить пользователя**, на какую build-систему направлять текущий вызов. Не выбирать молча.
- **Dependency version / CVE lookup:** `maven-mcp` family остаётся primary независимо от build-tool. `module.yaml` deps по факту остаются Maven coordinates — `maven-mcp:latest-version`, `maven-mcp:check-deps-vulnerabilities`, `maven-mcp:dependency-changes` работают как и для Gradle. Правило `rules/dependencies.md` § Plan-stage gate применяется в полном объёме.
- **API truth для библиотек:** без изменений — `ksrc` primary для JVM/Kotlin, `android docs search` primary для Android Jetpack/Compose/AGP/SDK. `kotlin-toolchain.org` **не** источник API truth для библиотек — только для **build configuration** (`module.yaml`, CLI, project lifecycle).
- **Guides:**
  - «Как настроить `module.yaml` для X / KMP target Y / Compose MP», «миграция с Gradle на Toolchain», «структура проекта в Toolchain», «product types в Toolchain» → **kotlin-toolchain.org primary**.
  - Все остальные Kotlin / JVM / Android guides — существующие цепочки из `rules/external-sources.md` без изменений.
- **IDE integration:** IntelliJ IDEA 2026.1.2+ через плагин Toolchain. Не имеет агентского endpoint'а (в отличие от `android studio` v1.0+) — для агента релевантна только CLI часть.

## Hard rules

- **Never run `kotlin update` automatically.** Apha → может ломать рабочий проект между релизами. Только по явному запросу пользователя.
- **Never run `kotlin init` automatically.** Аналог `android create` / `gradle init`: только когда пользователь явно просит scaffold нового проекта.
- **`kotlin publish` requires explicit user confirmation** — публикация модулей в repository видна вовне (см. `CLAUDE.md § Executing actions with care`). Та же категория действия, что `git push` / `gh pr create --ready`.
- **Не переключать Gradle-проект на Toolchain без запроса.** Миграция — продуктовое решение пользователя, не сторонний рефакторинг.
- **Surface Alpha при рекомендации Toolchain для нового проекта.** Документация остаётся authoritative для текущего синтаксиса, но «использовать в production» — отдельный dialog с пользователем.
- **Не ретраить `kotlin` как Toolchain после одного негативного disambiguation в той же сессии.** Использовать docs-only fallback.

## Fallback when CLI is missing or is legacy

Один раз уведомить пользователя и переключиться на docs-only режим:

| Task | Fallback |
|------|----------|
| Documentation, концепции, FAQ | `WebFetch https://kotlin-toolchain.org/latest/...` |
| `module.yaml` schema reference | `WebFetch https://kotlin-toolchain.org/latest/reference/project/` |
| Build / test / run / check | Если в проекте есть `build.gradle*` → Gradle; иначе заблокировано, спросить пользователя |
| Dependency lookup | `maven-mcp` family (без изменений) |

## Trust tier

`kotlin-toolchain.org` — **T2** (official curated docs, JetBrains) по таксономии `rules/external-sources.md`. Alpha-статус → понижать tier до **T3** для утверждений про *стабильность* и *production-ready* поведение. Для синтаксиса `module.yaml` и CLI команд (то что реально живёт в /latest/) — T2.

`kotlin-toolchain.org` входит в список **High-staleness libraries** в `rules/external-sources.md`: оба канала (API truth + guides) обязательны при работе с Toolchain. API truth для библиотек остаётся через `ksrc` / `android docs`; kotlin-toolchain.org даёт build-config guides.

## Output handling note

`kotlin <cmd>` обычно эмитит ANSI прогресс при сборке. При scripted-захвате последние строки — payload. `--log-level=warn` или `--log-level=error` снижает шум, если нужен только результат. Для верифицирующих flow в `/check` / `/acceptance` использовать `--log-level=warn`.
