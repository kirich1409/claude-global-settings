#!/bin/bash
# gate-receipt-reminder — Stop-хук: напоминает, что гейты `finalize` / `acceptance` не
# прогонялись на текущем состоянии кода.
#
# Зачем. Мандат гейтов живёт инструкцией в CLAUDE.md, то есть срабатывает, только если
# модель решит его применить. Замер (issue #93) дал 1 попадание из 6. Инструкция задаёт
# намерение, но не является механизмом; механизм — вот этот хук: он не в контексте модели,
# не тратит токены и срабатывает независимо от того, что модель решила.
#
# Детект детерминированный: не разбирать `last_assistant_message` на «готово» — это вернуло
# бы зависимость от суждения в место, где её труднее отладить. Смотреть только состояние
# репозитория и receipt-файлы.
#
# Первая версия НЕ блокирует: возвращает `additionalContext`. Блокирующий Stop-хук при
# ложном срабатывании воюет с пользователем, а сначала нужно увидеть частоту и точность
# срабатываний. Проверка `stop_hook_active` написана сразу — чтобы блокирующий вариант
# нельзя было включить без защиты от петли.
#
# Fail open везде: нет jq / git / не репозиторий / нет базы — exit 0. Сломанный хук не
# имеет права заклинить сессию.

set -uo pipefail

INPUT="$(cat)"

command -v jq  >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

jqr() { printf '%s' "$INPUT" | jq -r "$1" 2>/dev/null; }

# Защита от петли: Claude Code уже продолжает ход из-за stop-хука.
[ "$(jqr '.stop_hook_active // false')" = "true" ] && exit 0

# Фоновые задачи в полёте — ход не «завершён», сессия ждёт пробуждения. Поле появилось
# в 2.1.145; на старых версиях его нет, тогда jq вернёт 0 и проверка просто не сработает.
[ "$(jqr '(.background_tasks // []) | length')" != "0" ] && exit 0

CWD="$(jqr '.cwd // ""')"
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0

HASH_TOOL="$HOME/.claude/scripts/gate-diff-hash.sh"
[ -x "$HASH_TOOL" ] || exit 0

# Менялись ли исходники вообще. Пустой отпечаток пустого диффа — это sha256 пустого ввода;
# сравнивать с ним неудобно, поэтому спрашиваем список файлов напрямую.
CHANGED="$("$HASH_TOOL" --files 2>/dev/null)"
[ -z "$CHANGED" ] && exit 0

HASH="$("$HASH_TOOL" 2>/dev/null)" || exit 0
[ -z "$HASH" ] && exit 0

# Receipt засчитывается, только если записанный в нём отпечаток совпадает с текущим.
# Receipt трёхкоммитной давности не считается — именно этот случай хук и ловит.
have_receipt() {
  local pattern="$1"
  local f
  for f in swarm-report/*"$pattern"; do
    [ -f "$f" ] || continue
    grep -qF "$HASH" "$f" && return 0
  done
  return 1
}

MISSING=""
have_receipt "-quality.md"    || MISSING="finalize"
have_receipt "-acceptance.md" || MISSING="${MISSING:+$MISSING и }acceptance"

[ -z "$MISSING" ] && exit 0

FILE_COUNT="$(printf '%s\n' "$CHANGED" | grep -c . )"

MSG="Гейт не пройден на текущем коде: не прогонялся $MISSING. Изменено файлов исходного кода на ветке: $FILE_COUNT. Receipt с отпечатком $HASH в swarm-report/ отсутствует.

Задача не считается завершённой без обоих гейтов (CLAUDE.md § Принципы, скилл verification § The two gates): finalize отвечает за то, КАК написан код, acceptance — за то, ЧТО он делает. Исключения — правки документации, конфигурация без логики и однострочные механические изменения; исключение снимает церемонию, но не доказательство.

Если исключение применимо — сказать это пользователю явно и назвать, какое. Если нет — прогнать недостающий гейт до того, как объявлять работу готовой."

jq -nc --arg msg "$MSG" \
  '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $msg}}'
exit 0
