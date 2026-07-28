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

# Репозиторий ~/.claude — синхронизация

`~/.claude` (`kirich1409/claude-global-settings`, public) синхронизируется напрямую: правки tracked-файлов делаются в основном чекауте на `main` и уезжают на remote через `csync`. Ветка + PR — не модель по умолчанию, а инструмент по явной просьбе.

- Использовать `$HOME/.claude/...` в конфигах/hooks. Никогда не хардкодить `/Users/<username>/...`.
- **`csync`** (`hooks/sync-settings.sh`) — двусторонний синк: `add -A` → commit `sync <host> <date>` → fetch → rebase на `origin/main` → push. `.gitignore` работает как whitelist, поэтому `add -A` подхватывает только конфиг, но не память, сессии и scratch.
- **SessionStart auto-pull** (`hooks/auto-pull.sh`) — только тянет (ff-only). Незакоммиченные правки и неотправленные коммиты на `main` — нормальное рабочее состояние: хук сообщает о них и предлагает `csync`, но сам ничего не публикует. Расхождение (ahead + behind) он не разруливает — это делает rebase внутри `csync`.
- **Конфликт при rebase:** csync откатывает rebase и кладёт remote-версии рядом как `*.remote`. Смержить руками, удалить `.remote`, повторить `csync`.
- **`settings.json` мержится структурно** (`merge=json`, драйвер регистрируется в `.git/config` через `setup.sh`). Без регистрации git падает в дефолтный драйвер — тогда csync громко покажет конфликт, а не тихо испортит файл.
- **Секреты.** Репозиторий публичный, и прямой коммит проходит без ревью. Локальный гейт — pre-commit с gitleaks (`pip install pre-commit && pre-commit install`, конфиг в `.pre-commit-config.yaml`); в CI `gitleaks` и `validate` гоняются в том числе на push в `main`, но уже post-hoc. Красный workflow после push чинить сразу.
- **PR — по явной просьбе.** `scripts/cgs-pr.sh new <slug>` поднимает worktree+ветку, `scripts/cgs-pr.sh ship "<title>"` из worktree делает commit → push → PR → auto-merge → опрос → ff main → уборку. Не объявлять «синхронизировано» в момент push: auto-merge асинхронный, merged подтверждать опросом (`gh pr view <N> --json state`). Alias: `cgspr="$HOME/.claude/scripts/cgs-pr.sh"`.
- **Новая машина / онбординг:** `scripts/bootstrap-machine.sh` сводит чекаут машины на `origin/main` (ff-only; стоп при незапушенных локальных коммитах/правках, `--force` для жёсткого reset), проверяет `gh auth` и заводит локальные алиасы. Запускать вне активной Claude-сессии (иначе гонка с auto-pull-хуком).
