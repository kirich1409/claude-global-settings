#!/bin/bash
# SessionStart — уборка локального state, который встроенный cleanupPeriodDays не покрывает.
#
# security/: плагин security-guidance пишет security_warnings_state_<session>.json (+ .lock)
# на каждую сессию и никогда не удаляет — каталог растёт бесконечно (наблюдалось 1400+ файлов).
# Файл нужен только живой сессии; старше 30 дней — мёртвые сессии. Best-effort: всегда exit 0,
# чтобы уборка никогда не ломала старт сессии.

find "$HOME/.claude/security" -maxdepth 1 -name 'security_warnings_state_*' -mtime +30 -delete 2>/dev/null || true

exit 0
