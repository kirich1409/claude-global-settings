---
name: cc-config-wizard
description: Greenfield CLI-мастер глубокой настройки Claude Code для проекта — архитектурный контекст и граничные факты движка
type: project
---

V0 инструмента: CLI-мастер, который использует **установленный Claude Code как движок** (анализ проекта + авторинг контента правил), проводит опросник (ядро + модули по типу проекта), затем детерминированно применяет конфиг: пишет CLAUDE.md и `.claude/rules/*.md`, ставит плагины, настраивает subagents/skills/hooks/settings.json/MCP. Сценарии: with-scratch и adopt (поднять существующий CLAUDE.md). Поддержка: ручной `refresh` (повторный анализ + diff, propose-only). Отдельная подсистема — курируемая база знаний «что хорошо для Claude» (плагины/флоу/настройки), stale-prone.

**Why:** проектируется с нуля, нужны архитектурные варианты с trade-offs для оркестратора (финальный вердикт не за экспертом).

**How to apply:** при возврате к теме — варианты, не вердикт; ранжировать по риску. Главная ось напряжения — недетерминизм LLM локализовать за схематизированной границей Analyzer-output ↔ Config-applier-input.

Граничные факты (проверено 2026-05-27, версии будут дрейфовать — перепроверять):
- Claude Code headless богатый: `--print`, `--output-format json|stream-json`, **`--json-schema` для structured output**, `--permission-mode`, `--allowedTools`, `--mcp-config`, `--agents` (inline JSON персоны), `--plugin-dir/--plugin-url`, **`--bare`** (без хуков/плагинов/CLAUDE.md-autodiscovery — гермечный режим для воспроизводимости движка).
- SDK: TS `@anthropic-ai/claude-agent-sdk` 0.3.x (живой), Python `claude-agent-sdk` 0.2.x. Базовый `@anthropic-ai/sdk` 0.99.x.
- Следствие: выбор стека инструмента (JVM/Go) ⟹ subprocess-only, т.к. Agent SDK только TS/Python. Зависимость 6⟸1.
