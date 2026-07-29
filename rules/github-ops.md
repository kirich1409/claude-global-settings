# Операции с трекером GitHub / GitLab

Детали команд и GraphQL живут в скриптах — читать заголовочный блок скрипта, когда нужен точный
рецепт.

## Toolkit `$HOME/.claude/scripts/gh/`

Идемпотентные, безопасные по timeout хелперы; предпочитать их сырому `gh project` и ручному
GraphQL. Каждый оборачивает сетевые вызовы в `gh_with_timeout` из `_common.sh`, поэтому зависший
API прерывается, а не замораживает агента.

| Скрипт | Что делает |
|---|---|
| `transition_status.sh <issue> <status>` | двигает issue по доске (Projects v2 через GraphQL) или fallback по лейблам; `--dry-run` |
| `get_completion_signal.sh <issue>` | завершён ли issue: merged PR > open PR > none |
| `get_dependencies.sh <issue>` | блокирующие зависимости: sub-issues и «blocked by #N» / «depends on #N» |
| `list_issues.sh` / `fetch_issue.sh` | запрос и получение issues; `list_issues.sh` отдаёт `updated_at` для всего списка, тела там нет намеренно; `fetch_issue.sh --with-comments` добавляет тред |
| `add_comment.sh` / `link_pr.sh` | marker-идемпотентный комментарий и привязка PR |

## Идемпотентность

Сессия может быть сжата, перебуждена или запущена повторно — мутации не должны применяться дважды:

- **Read-before-write** для статуса: читать текущее состояние, писать только при отличии (скрипты
  возвращают `action: noop`, если уже там).
- **Hidden-marker** для комментариев и ссылок: сканировать `<!-- issue-manager:<key> -->` перед
  постингом, пропускать при наличии. Никогда не постить комментарий без проверки маркера.

## Доска Projects v2

| Этап | Статус | Триггер |
|---|---|---|
| работа начата, draft PR открыт | **In Progress** | `create-pr --draft` |
| PR готов к ревью | **In Review** | `create-pr --promote` |
| смержен | **Done** | post-merge |
| заблокирован | label `status:blocked` | поднят истинный блокер |

Двигать через `transition_status.sh <issue> <in-progress|in-review|done|blocked>`, не вручную через
`gh project item-edit`. Скрипт сам находит связанный Project v2, при отсутствии проекта или прав
откатывается к open/closed и лейблам `status:*`.

## Абстракция платформы

Определять платформу по remote host, затем маппить: `gh` ↔ `glab`, `gh pr` ↔ `glab mr`,
`gh api graphql` ↔ `glab api`. Думать «переместить карточку», «смержен ли», «запросить ревью
снова» и выбирать CLI по определённой платформе, не предполагая `github.com`.

## Anti-hang

- Новые вызовы `gh` вне toolkit оборачивать в timeout: синхронный `gh` без него заморозит агента
  при зависании API.
- **Никогда не запускать блокирующие watchers в главной сессии:** `gh run watch`,
  `gh pr checks --watch` блокируют на всё время CI. Делегировать в фон, использовать
  `ScheduleWakeup` или отдать ожидание платформе ([[github-merge-policy]]).
- Считать `pending` как «ждать», никогда как «сбой».
