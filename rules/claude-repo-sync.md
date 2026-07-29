---
paths:
  - "**/.claude/CLAUDE.md"
  - "**/.claude/rules/**"
  - "**/.claude/settings*.json"
  - "**/.claude/hooks/**"
  - "**/.claude/scripts/**"
  - "**/.claude/skills/**"
  - "**/.claude/agents/**"
---

# Синхронизация репозитория ~/.claude

`~/.claude` — публичный репозиторий `kirich1409/claude-global-settings`, синхронизируемый между
машинами. Правки tracked-файлов идут **прямо в `main`**.

Нужен ли PR — решает сам репозиторий: branch protection и инструкции проекта, а не глобальный
харнес. Здесь защиты нет, поэтому прямой коммит — штатный путь.

- Использовать `$HOME/.claude/...` в конфигах и хуках. Никогда не хардкодить `/Users/<username>/...`.
- **`main` — рабочая ветка основного чекаута.** Грязное дерево и коммиты впереди origin — обычное
  рабочее состояние, а не авария.
- **Доставляет `csync`** (`hooks/sync-settings.sh`): fetch → `add -A` → commit → rebase на
  `origin/main` → push. Конфликт при rebase останавливает csync громко и ничего не меняет — это
  реальное решение, а не деталь синхронизации.
- **SessionStart auto-pull только тянет.** Он никогда не коммитит и не пушит; при грязном или
  ahead-состоянии просто сообщает и пропускает pull.
- Untracked (память, `swarm-report/`, `projects/`, `agent-memory`) в синхронизацию не входит.
- **PR — опциональный путь** для изменения, которое стоит отревьюить: `scripts/cgs-pr.sh new <slug>`
  поднимает worktree и ветку, `scripts/cgs-pr.sh ship "<title>"` из worktree делает
  commit → push → PR → auto-merge → опрос → ff main → уборку. При зависшем PR worktree остаётся
  для разбора.
- **Новая машина:** `scripts/bootstrap-machine.sh` сводит чекаут на `origin/main` (ff-only; стоп при
  незапушенных локальных коммитах, `--force` для жёсткого reset), проверяет `gh auth` и заводит
  локальные алиасы. Запускать вне активной Claude-сессии, иначе гонка с auto-pull.
