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

# Репозиторий ~/.claude — PR-only

`~/.claude` (`kirich1409/claude-global-settings`, public) работает в строгой PR-модели: `main` всегда чистая, всё доставляется через PR с auto-merge. Это распространяется и на главную сессию — правило «`~/.claude/**` можно редактировать напрямую» (orchestration) разрешает *кто* правит, но *как* доставляется — только через PR.

- Использовать `$HOME/.claude/...` в конфигах/hooks. Никогда не хардкодить `/Users/<username>/...`.
- **`main` — единственная рабочая ветка основного чекаута.** Никогда не коммитить, не пушить и не редактировать tracked-файлы прямо на `main`. `enforce_admins: false` позволяет владельцу технически обойти защиту — не пользоваться этим, модель именно PR.
- **`csync` и SessionStart auto-pull только синхронизируют (pull):** fetch + `merge --ff-only origin/main`. Они не коммитят/не пушат/не открывают PR. Если они громко сигналят «main грязный / ahead» — значит правки попали на `main`; вынести их в ветку, `main` сбросить на `origin/main`.
- **Любая правка tracked-файла** (CLAUDE.md, rules/, settings*.json, hooks/, scripts/, skills/, agents/) — в **отдельной ветке, предпочтительно через worktree** (`git worktree add -b chore/<slug> .worktrees/<slug> origin/main` из `~/.claude`; whitelist-`.gitignore` игнорирует `.worktrees/` автоматически), затем PR. Untracked (память, `.remember`, `swarm-report`, `projects/`, `agent-memory`) — не tracked, правятся напрямую, PR не требуют.
- **Доставка — ответственность того, кто внёс изменение** (агент/сессия), не sync-скрипта.
- **Auto-merge:** `gh pr merge <N> --auto --squash --delete-branch`. Required-чек `scan` (gitleaks на `pull_request`) проходит сам, approve не нужен (0 reviewers) → PR мержится без вмешательства. Не объявлять «синхронизировано» в момент push — auto-merge асинхронный; merged подтверждать отдельным опросом (`gh pr view <N> --json state`).
- **После merge:** ff основного чекаута (`csync` или `git merge --ff-only origin/main`). Stall-риск: strict-чек + GitHub не авто-обновляет ветки PR → при гонке машин второй PR устаревает и auto-merge зависает; ловить open-but-stale PR громко, не считать `--auto` гарантией merge.
- Если `--delete-branch` при auto-merge не удалил remote-ветку (`delete_branch_on_merge: false`) — удалить вручную: `git push origin --delete <branch>`.
- **Helper:** `scripts/cgs-pr.sh new <slug>` поднимает worktree+ветку; после правок `scripts/cgs-pr.sh ship "<title>"` (из worktree) инкапсулирует весь хвост (commit → push → PR → auto-merge → опрос → ff main → уборка). При зависшем/закрытом PR worktree остаётся для разбора. Для удобства завести alias `cgspr="$HOME/.claude/scripts/cgs-pr.sh"` (alias локален, не синкается).
- **Новая машина / онбординг:** `scripts/bootstrap-machine.sh` сводит чекаут машины на каноничный `origin/main` (ff-only; стоп при незапушенных локальных коммитах/правках, чтобы не потерять — `--force` для жёсткого reset), проверяет `gh auth` и заводит локальные алиасы. Запускать вне активной Claude-сессии (иначе гонка с auto-pull-хуком).
