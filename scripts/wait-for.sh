#!/usr/bin/env bash
# wait-for.sh — ожидание по условию с верхней границей (rules/task-execution.md § Ожидание по условию, не по таймеру).
# Опрашивает команду-условие до успеха; при таймауте громко падает с последним выводом условия.
#
# Usage:
#   wait-for.sh [-t timeout_sec] [-i interval_sec] [-q] -- cmd [args...]
#
#   -t  верхняя граница в секундах (default: 60)
#   -i  шаг опроса в секундах (default: 2)
#   -q  не печатать сообщение об успехе
#
# Exit codes: 0 — условие наступило; 124 — таймаут; 2 — ошибка использования.
#
# Examples:
#   wait-for.sh -t 30 -- test -f /tmp/build.done
#   wait-for.sh -t 120 -i 5 -- pgrep -q Onset
#   wait-for.sh -t 60 -- sh -c 'grep -q "Server started" server.log'
set -euo pipefail

timeout=60
interval=2
quiet=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t) timeout=$2; shift 2 ;;
    -i) interval=$2; shift 2 ;;
    -q) quiet=1; shift ;;
    --) shift; break ;;
    *)  echo "wait-for: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ $# -eq 0 ]]; then
  echo "usage: wait-for.sh [-t timeout_sec] [-i interval_sec] [-q] -- cmd [args...]" >&2
  exit 2
fi

deadline=$(( $(date +%s) + timeout ))
attempt=0
last_output=""

while true; do
  attempt=$((attempt + 1))
  if last_output=$("$@" 2>&1); then
    [[ $quiet -eq 1 ]] || echo "wait-for: condition met after ${attempt} attempt(s)"
    exit 0
  fi
  if (( $(date +%s) >= deadline )); then
    echo "wait-for: TIMEOUT — condition not met in ${timeout}s (${attempt} attempts): $*" >&2
    [[ -n "$last_output" ]] && echo "wait-for: last output: ${last_output}" >&2
    exit 124
  fi
  sleep "$interval"
done
