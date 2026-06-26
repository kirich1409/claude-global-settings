# Task Execution

## Error handling during tasks

For **blocking** errors (failures that prevent continuing). For investigation without a blocker, follow Communication Style (dig silently, report once).

1. Notify the user immediately that an error occurred.
2. Diagnose and attempt to fix autonomously.
3. Report what happened and what was done.
4. If one attempt is not enough — stop and ask the user how to proceed.

## Root cause over symptom suppression (подход к фиксу багов)

- Баг-фикс устраняет **причину**, а не гасит симптом. Прежде чем обернуть падающее место в `try/catch`, добавить null-guard / fallback / `@Suppress` — спроси: *а корректно ли вообще то, что здесь падает?* Часто «защита» прячет то, что вызов / API / логика изначально неверны.
- Если defensive-обёртка (try/catch, fallback, retry, null-coalesce, suppress) **и есть весь фикс** — это красный флаг. Она допустима только **поверх** устранённой причины, как ремень безопасности.
- Подавление не должно быть **молчаливым**: проглоченная ошибка логируется/сигналит (см. [[logging]]). Тихий отказ (данные не загрузились, событие не пришло) хуже краша — он невидим в мониторинге.
- Причину подтверждай **эмпирически / по источнику** (`CLAUDE.md` Principles → empirical check; [[external-sources]] trust tiers), а не реконструкцией из головы.
- Чини **все** экземпляры паттерна, не только тот, что в трейсе.
- Закрепляй **регресс-тестом** на наблюдаемый контракт («не пробрасывает», «не воспроизводится»), даже если точный сбой в тесте не воспроизводим.

## Scope creep

If a task turns out significantly more complex than it appeared — stop, report what was found, propose to revise scope or approach before proceeding.

## Large output handling

For commands that may produce large output (test runs, git logs, build output, API responses, dependency trees) — prefer context-mode over raw Bash. The PreToolUse hook handles Bash automatically; explicitly use `mcp__plugin_context-mode_context-mode__execute` for large MCP tool results.
