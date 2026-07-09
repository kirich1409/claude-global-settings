# Адаптация ~/.claude для Cursor CLI (`cursor-agent`)

Портирование поведенческого слоя настройки Claude Code на Cursor CLI. Контент живёт здесь (синкается через PR-модель `~/.claude`); per-machine symlink'и в `~/.cursor` ставит `scripts/bootstrap-machine.sh`.

Проверено на `cursor-agent 2026.05.24`.

## Механизм (что куда мапится)

| Слой Claude Code | Механизм в Cursor CLI | Доставка |
|---|---|---|
| Глобальный `~/.claude/CLAUDE.md` + always-on rules | `~/AGENTS.md` (essentials) | symlink `~/AGENTS.md` → `cursor/AGENTS.md` |
| Кастомные агенты (`~/.claude/agents/`, 18) | `~/.cursor/agents/` (сгенерированные копии с вырезанным `model:`) | bootstrap генерирует из `~/.claude/agents` |
| Skills семейства developer-workflow | авточтение `~/.claude/skills/` | нативно, без symlink |
| Always-on rules (детальные) | нативные Cursor `.mdc` rules (Agent-Selected: `description`, `alwaysApply: false`) | `cursor/rules/*.mdc` → symlink в `~/.cursor/rules/` |
| Paths-scoped rules (Kotlin/Swift/Compose/Gradle…) | нативные Cursor `.mdc` rules (Auto-Attached: `globs`) | `cursor/rules/*.mdc` → symlink в `~/.cursor/rules/` |
| shell-скрипты (`scripts/gh/`, `ast-index`) | работают как есть | — |

### Почему именно так (эмпирические факты)

- `cursor-agent` **не** грузит глобальный `~/.claude/CLAUDE.md` и `~/.claude/rules` сам. Проверено: из нейтральной директории `CLAUDE_MD:NONE`, `RULES:NONE`.
- `~/AGENTS.md` **глобален**: Cursor поднимается вверх по дереву каталогов (upward-walk) от cwd, **сквозь границу `.git`**, вплоть до `$HOME`. Значит один `~/AGENTS.md` применяется во всех проектах под `$HOME`. Проверено sentinel-тестами.
- Агенты в формате Claude Code Cursor загружает, игнорируя незнакомые поля (`tools:`), но поле **`model:` он ЧТИТ** и пиннит эту модель. `~/.claude/agents` пинят `opus`/`sonnet` (для Claude Code — верно, там выбора нет). Чтобы Cursor не форсил конкретную модель, bootstrap генерирует копии в `~/.cursor/agents` с **вырезанной строкой `model:`** → Cursor использует inherit/auto (свободный выбор). Проверено: `/architecture-expert` маршрутизируется; агенты стартовали на пиненных opus/sonnet до стрипа.
- Skills читаются из `~/.claude/skills` нативно (legacy-compat). Проверено: `finalize`/`check` видны.
- **Нативные `.mdc` rules из `~/.cursor/rules/` работают глобально в CLI** (у CLI ЕСТЬ file-based глобальная локация rules, вопреки прежнему предположению). Проверено sentinel-тестами: `alwaysApply: true` грузится каждую сессию; `globs: **/*.kt` auto-attach'ится, когда `.kt`-файл попадает в контекст (прочитан); multi-glob через запятую (`**/*.kt, **/*.kts`) тоже работает. Поэтому paths-scoped правила — нативные `.mdc` с `globs` (настоящий file-glob триггер), а не skills (в этом билде `paths:` у skills игнорируется).
- Rules держатся в `cursor/rules/` (а не в `~/.claude/rules/`) и symlink'аются в `~/.cursor/rules/` — Claude Code их не видит (читает `~/.claude/rules`), смешивания нет. Symlink «живой» → правка `cursor/rules/*.mdc` действует сразу, без дрейфа.

## Always-on слой (essentials)

`cursor/AGENTS.md` содержит только непререкаемое ядро (стратегия «essentials», не полный порт — чтобы не раздувать контекст каждой сессии): §Нельзя нарушать, язык/общение, принципы, границы оркестрации, workflow-gates, указатель на детальные правила. Детальные always-on правила — нативные `.mdc` rules с `alwaysApply: false` (Agent-Selected), грузятся по релевантности (та же ленивая загрузка, что задумана essentials-стратегией). Paths-scoped — `.mdc` с `globs`, грузятся при работе с соответствующими файлами.

## Установка на машине

```
bash ~/.claude/scripts/bootstrap-machine.sh
```

Создаёт symlink'и `~/AGENTS.md`, `~/.cursor/rules/*.mdc` и **генерирует** копии агентов в `~/.cursor/agents` (с вырезанным `model:`). Также чистит устаревшие битые symlink'и в `~/.cursor/skills` от прежней (skills-based) схемы. Идемпотентно; реальные (не-symlink) файлы не затирает. Запускать вне активной Claude-сессии.

**Важно:** агенты в `~/.cursor/agents` — снимки, регенерируются на каждом запуске bootstrap. После добавления/правки агента в `~/.claude/agents` — **перезапустить bootstrap**, иначе Cursor не увидит изменение (в отличие от «живого» symlink).

## Что НЕ портировано (отложено)

Осознанно вне scope этой адаптации (можно добавить позже):

- **Hooks** — `settings.json` hooks (`SessionStart`/`PreToolUse`/`PostToolUse`/`UserPromptSubmit`/`Stop`) → `~/.cursor/hooks.json` (другой формат, другие имена событий: `sessionStart`/`beforeShellExecution`/`afterFileEdit`/…). Последствие: ast-index freshness, auto-pull, context-mode, statusline в Cursor не работают.
- **Permissions** — `settings.json permissions` → `~/.cursor/cli-config.json` (`Shell()/Read()/Write()/WebFetch()` токены, иной синтаксис).
- **MCP** — сервера настраиваются отдельно в `mcp.json` (Cursor не читает `settings.json mcpServers`).
- **Memory** — система `MEMORY.md`/`memory/`/`.remember` (нативной памяти в CLI нет; только через hooks/MCP).

## Ограничения / caveat'ы

- `ast-index`: CLI работает, но freshness-хуки — механизм Claude Code; в Cursor обновлять индекс вручную (`ast-index update`/`rebuild`).
- Детальные always-on rules (`.mdc` с `alwaysApply: false`) грузятся **по релевантности** (Agent-Selected по description), а не безусловно как в Claude Code. Ядро, которое обязано применяться всегда, — в `AGENTS.md`. Если нужно, чтобы конкретное правило применялось всегда — поставить в его `.mdc` `alwaysApply: true` (ценой контекста каждой сессии).
- Билд Cursor 6-недельной давности на момент адаптации; на более новых билдах авточтение `~/.claude/agents` на user-level может заработать напрямую. Но генерация копий в `~/.cursor/agents` всё равно нужна ради стрипа `model:` — прямое авточтение `~/.claude/agents` вернуло бы пины `opus`/`sonnet`.
- **`~/AGENTS.md` и `~/.cursor/rules/*.mdc` глобальны только для проектов под `$HOME`.** Upward-walk идёт от cwd вверх; проект вне `$HOME` (например `/Volumes/...`, `/tmp`) их не увидит. Проверено: из `/private/tmp` слой не грузится, из под-каталога `$HOME` — грузится.
- **Дрейф — только у агентов.** `AGENTS.md` и `.mdc` rules — «живые» symlink'и на синкаемый источник, правка действует сразу. Агенты в `~/.cursor/agents` — снимки (нужна регенерация через `model:`-стрип), после правки `~/.claude/agents` перезапустить bootstrap.
