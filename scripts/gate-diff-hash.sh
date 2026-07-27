#!/bin/bash
# gate-diff-hash — канонический отпечаток изменений исходного кода на текущей ветке.
#
# Один и тот же отпечаток пишут гейты (`finalize`, `acceptance`) в свои receipt-файлы и
# считает Stop-хук `gate-receipt-reminder.sh`. Совпадение означает «гейт видел ровно этот
# код». Считать его в двух местах разными командами нельзя — разъедется молча, поэтому
# формула живёт здесь одна.
#
# Почему отпечаток диффа, а не SHA коммита: типовой поток — прогнать гейт, потом
# закоммитить, потом переписать историю ребейзом. Привязка к коммиту сбрасывала бы гейт
# на каждой такой операции, хотя код не менялся. Отпечаток диффа реагирует на содержимое.
#
# Область — только исходники (расширения из rules/code-style.md). Правки документации и
# конфигов гейт не сбрасывают; у них своя проверка (`validate-config`, схема, dry run).
#
# Usage: scripts/gate-diff-hash.sh            → отпечаток на stdout
#        scripts/gate-diff-hash.sh --files    → список затронутых исходников, по одному в строке
# Exit:  0, либо 1 если не git-репозиторий.

set -uo pipefail

git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "not in a git repo" >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)" || exit 1

# Расширения исходников — синхронно с `paths:` в rules/code-style.md.
PATHSPEC=(
  '*.kt' '*.java' '*.swift' '*.m' '*.mm' '*.js' '*.jsx' '*.ts' '*.tsx'
  '*.py' '*.go' '*.rs' '*.cs' '*.c' '*.cc' '*.cpp' '*.h' '*.hpp' '*.rb' '*.php'
)

# База ветки: merge-base с дефолтной. На самой дефолтной ветке базы нет — тогда в расчёт
# идёт только рабочее дерево против HEAD.
default_branch() {
  local d
  d="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" && { echo "${d#origin/}"; return; }
  for c in main master; do
    git show-ref --verify --quiet "refs/heads/$c" && { echo "$c"; return; }
  done
  echo main
}

DEF="$(default_branch)"
BASE="$(git merge-base HEAD "origin/$DEF" 2>/dev/null \
     || git merge-base HEAD "$DEF" 2>/dev/null \
     || echo HEAD)"

sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256; else sha256sum; fi; }

if [ "${1:-}" = "--files" ]; then
  {
    git diff --name-only "$BASE" -- "${PATHSPEC[@]}"
    git ls-files --others --exclude-standard -- "${PATHSPEC[@]}"
  } | LC_ALL=C sort -u
  exit 0
fi

{
  # Закоммиченные + незакоммиченные изменения относительно базы, ограниченные исходниками.
  git diff "$BASE" -- "${PATHSPEC[@]}"
  # Новые файлы ещё не в индексе — diff их не видит, но гейт обязан их покрывать.
  git ls-files --others --exclude-standard -- "${PATHSPEC[@]}" | LC_ALL=C sort | while IFS= read -r f; do
    printf '=== untracked: %s\n' "$f"
    cat -- "$f" 2>/dev/null
  done
} | sha | cut -d' ' -f1
