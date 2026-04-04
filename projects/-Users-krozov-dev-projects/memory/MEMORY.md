# Project Memory

## Testing Plugin (`~/.claude/plugins/testing`)

### Skills
- `testing:unit-tests` — генерация unit-тестов для Android/KMP проектов
- `testing:lint` — запуск линтера
- `testing:ui-smoke` — smoke-тестирование Android UI через MCP mobile tools

### Agents
- `testing:test-explorer` (haiku, cyan) — анализ тест-стека проекта для unit-tests скилла
- `testing:screen-discovery` (haiku, purple) — находит экраны/флоу из кода проекта для ui-smoke скилла

### File structure
```
~/.claude/plugins/testing/
  agents/
    test-explorer.md
    screen-discovery.md
  skills/
    unit-tests/SKILL.md + references/
    lint/SKILL.md + references/
    ui-smoke/SKILL.md + references/
      references/crash-patterns.md
      references/interaction-heuristics.md
```

### SKILL.md frontmatter format
```yaml
---
name: Human Readable Name
description: >
  Use this skill when the user asks to "...", "...", or invokes "/skill-name".
version: 0.x.0
---
```

### Agent .md frontmatter format
```yaml
---
name: agent-name
description: One-line description of what the agent returns.
tools: Glob, Grep, LS, Read
model: haiku
color: cyan
---
```

## Android Projects (~/dev/projects)
- `Alfa-Kassa-Android` — кассовое приложение
- `abm-uikit` — UI-kit
- `alfa-business-android-0910` — бизнес приложение
- `insnc-android` / `insnc-ios` — страховое приложение
