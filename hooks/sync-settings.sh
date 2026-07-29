#!/bin/bash
# csync — двусторонняя синхронизация ~/.claude с origin/main. Usage: csync
#
# Модель: правки идут прямо в main. csync коммитит локальные изменения, ребейзит на
# origin/main и пушит. Грязный или ahead main — нормальное рабочее состояние, не авария.
#
# Нужен ли PR — решает сам репозиторий (branch protection, инструкции проекта), а не
# глобальный харнес. Для изменения, которое стоит отревьюить, есть scripts/cgs-pr.sh.

set -euo pipefail

LOCK="/tmp/.claude-sync.lock"
exec 9>"$LOCK"
perl -e 'use Fcntl qw(:flock); open(F, ">&=9"); flock(F, LOCK_EX|LOCK_NB) or die' 2>/dev/null \
  || { echo "Another csync is running."; exit 1; }

cd "$HOME/.claude"

# Clean up stale rebase state from a previous crash
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
  git rebase --abort 2>/dev/null || true
fi

# csync only ever syncs the main checkout's main branch.
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
if [ "$BRANCH" != "main" ]; then
  echo "⚠ Not on main (on '$BRANCH'). csync only syncs main; switch to main first."
  exit 1
fi

# Fetch — network failure is loud, not silent.
git fetch --quiet origin || { echo "Fetch failed (network?)."; exit 1; }

# Commit local work, if any.
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  git add -A
  git commit --quiet -m "sync $(date '+%Y-%m-%d %H:%M')" || true
fi

# Rebase onto origin/main. A conflict stops loudly — it is a real decision, not a sync detail.
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
if [ "$BEHIND" -gt 0 ]; then
  if ! git rebase --quiet origin/main; then
    git rebase --abort 2>/dev/null || true
    echo "⚠ Rebase onto origin/main hit a conflict — resolve manually, csync changed nothing."
    exit 1
  fi
  echo "Rebased onto origin/main (was $BEHIND behind)."
fi

# Push whatever is ahead.
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
if [ "$AHEAD" -gt 0 ]; then
  git push --quiet origin main && echo "Pushed $AHEAD commit(s)." || { echo "Push failed."; exit 1; }
else
  echo "Up to date."
fi
