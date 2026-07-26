#!/usr/bin/env bash
# InstructionsLoaded: пишет в лог, какой instruction-файл загрузился, почему и какой ценой.
# Нужен, чтобы объём загружаемого контекста был наблюдаемой метрикой, а не ощущением.
# Событие side-effects-only: код возврата игнорируется, решений не принимает.
set -uo pipefail

LOG="${CLAUDE_INSTRUCTIONS_LOG:-$HOME/.claude/instructions-loaded.log}"

input=$(cat)
# jq может отсутствовать — тогда молча выходим, диагностика не должна ломать сессию.
command -v jq >/dev/null 2>&1 || exit 0

reason=$(jq -r '.load_reason // "?"' <<<"$input")
path=$(jq -r '.file_path // "?"' <<<"$input")
# Оценка веса: байты и грубая прикидка токенов (4.17 b/t — замерено на этом репо).
# file_content на 2.1.220 приходит пустым, поэтому размер берём с диска по file_path.
bytes=$(jq -r '(.file_content // "") | length' <<<"$input")
[ "${bytes:-0}" -eq 0 ] && [ -f "$path" ] && bytes=$(wc -c < "$path" | tr -d ' ')
tokens=$(( ${bytes:-0} * 100 / 417 ))

mkdir -p "$(dirname "$LOG")"
printf '%s\t%s\t%s\t%sb\t~%st\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" "$path" "$bytes" "$tokens" >> "$LOG"

exit 0
