# drive-to-merge — подготовка в фазе 1

Определение платформы, получение метаданных, предусловия и схема файла состояния. Грузится SKILL.md по
требованию.

## 1.1 Определить платформу

Извлечь хост из URL remote и прощупать соответствующий CLI. Не искать regex'ом литералы `github.com` и
`gitlab`: так теряются GitHub Enterprise Server и self-hosted GitLab.

```bash
REMOTE_URL=$(git remote get-url origin)
HOST=$(echo "$REMOTE_URL" | sed -E 's#^(https?://|git@)([^/:]+)[/:].*#\2#')

if gh auth status --hostname "$HOST" >/dev/null 2>&1; then
  PLATFORM=github
elif glab auth status --hostname "$HOST" >/dev/null 2>&1 || glab config get --global gitlab_uri 2>/dev/null | grep -q "$HOST"; then
  PLATFORM=gitlab
else
  echo "Unknown host $HOST — authenticate gh or glab against it and rerun." >&2
  exit 1
fi
```

## 1.2 Получить метаданные PR/MR

```bash
# GitHub
PR_INFO=$(gh pr view --json id,number,baseRefName,headRefName,title,body,isDraft,state,url,\
statusCheckRollup,reviewDecision,mergeable,mergeStateStatus,labels,closingIssuesReferences)
PR_NUMBER=$(jq -r .number <<<"$PR_INFO")
PR_URL=$(jq -r .url <<<"$PR_INFO")
IS_DRAFT=$(jq -r .isDraft <<<"$PR_INFO")
BASE=$(jq -r .baseRefName <<<"$PR_INFO")
HEAD=$(jq -r .headRefName <<<"$PR_INFO")
PR_NODE_ID=$(jq -r .id <<<"$PR_INFO")     # graphql node id из того же вызова — без лишнего похода
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
OWNER=${REPO%/*}; REPO_NAME=${REPO#*/}

# Node id репозитория — нужен для перепроверки владения тредом перед каждым POST.
REPO_NODE_ID=$(gh api graphql -f query='query($o:String!,$n:String!){repository(owner:$o,name:$n){id}}' \
  -F o="$OWNER" -F n="$REPO_NAME" --jq '.data.repository.id')
# COPILOT_NODE_ID разрешается лениво в фазе 3.6 и кэшируется в шапке файла состояния.

# GitLab
MR_INFO=$(glab mr view --output json)
MR_IID=$(jq -r .iid <<<"$MR_INFO")
MR_URL=$(jq -r .web_url <<<"$MR_INFO")
IS_DRAFT=$(jq -r '.title | startswith("Draft:")' <<<"$MR_INFO")
BASE=$(jq -r .target_branch <<<"$MR_INFO")
PROJECT=$(glab repo view --output json | jq -r '.path_with_namespace | @uri')
```

PR/MR уже смержен или закрыт — остановиться и сообщить финальное состояние.

### Определение политики слияния

После получения метаданных репозитория вывести политику слияния для этого прогона. Записать в файл
состояния как `Merge policy:`.

1. **Явная конфигурация в `CLAUDE.md`** — просканировать `CLAUDE.md` репозитория, если он есть, на
   строку вида:

   ```
   Merge policy: auto
   Merge policy: team-strict
   ```

   Брать первое совпадение.

2. **Явная конфигурация в `.claude/settings.json`** — ключ `driveToMerge.mergePolicy`, значения
   `"auto"` либо `"team-strict"`.

3. **Откат: эвристика «организация или личный репозиторий»** (только GitHub):

   ```bash
   IS_ORG=$(gh repo view --json isInOrganization -q .isInOrganization)
   # true → team-strict; false → auto
   ```

   Для GitLab по умолчанию `team-strict`, когда namespace проекта групповой, и `auto`, когда личный.

Семантика политик:

- `auto` — `--merge=auto` снимает гейт слияния и может пользоваться нативным auto-merge платформы.
- `team-strict` — гейт слияния спрашивает всегда, в любом режиме; `--when-pipeline-succeeds` в GitLab
  выключен, пока пользователь явно не передал `--native-auto-merge` при вызове.

## 1.3 Предусловия

Прерваться с внятным сообщением, если нарушено любое:

- текущая ветка совпадает с head-веткой PR; иначе прервать словами «сначала переключись на `<head>`;
  этот скилл ветки сам не переключает»;
- локальная ветка получена из remote и не отстаёт от его head (`git fetch origin && git status -sb`);
- `gh auth status` либо `glab auth status` — токен валиден;
- базовая ветка всё ещё существует в remote.

## 1.4 Файл состояния

`swarm-report/<slug>-drive-state.md`. Слаг — `<ветка-без-префикса>-pr<PR_NUMBER>` (ветка `fix/login` в
PR 42 → `login-pr42`). Номер PR разводит параллельные ветки, которые иначе дали бы один и тот же слаг
(`feature/login` и `fix/login`, либо два переоткрытия одной ветки).

Проверить, что `swarm-report/` игнорируется git, запустив `git check-ignore -q swarm-report/`: код 0 —
игнорируется, ненулевой — нет. При ненулевом прервать со словами «`swarm-report/` не игнорируется git;
добавь `swarm-report/` в `.gitignore` и запусти снова». `.gitignore` автоматически не править: это
создаёт посторонний дифф внутри цикла ведения PR и удивляет пользователя.

### Схема (markdown, разбираемая машиной при возобновлении)

```markdown
# Drive to Merge — <заголовок PR>

URL: <URL PR>
Platform: github | gitlab
Mode: reviews=<auto|ask> merge=<auto|ask|never> rebase=<yes|no> | dry-run
Merge policy: auto | team-strict
Principal: <@actor>            # gh api user --jq .login
Repository node id: <graphql node id репозитория>
PR node id: <graphql node id пул-реквеста>
Copilot node id: <graphql node id copilot-pull-request-reviewer либо `unavailable`>
Started: <ISO8601>
Status: running | waiting-for-user | waiting-native-auto-merge | merged | blocked

## Branch change model
analyzed_through_sha: <сокращённый sha, по состоянию на который модель актуальна, либо пусто до первой сборки>

<компактное прозаическое описание того, что делает ветка: затронутые области и файлы, ключевые
поведения, инварианты и введённые контракты — несколько строк, обновляемых дельтой каждый раунд>

## Rounds
| # | Started | Trigger | CI | New comments | Actions | Outcome |
|---|---------|---------|----|--------------|---------|---------|

## Commitments (открытые треды, которыми владеет этот скилл)
| thread_id | category | delegated_to | fix_commit_sha | replied | resolved |
|-----------|----------|--------------|----------------|---------|----------|

`fix_commit_sha` держит сокращённый sha коммита, закрывшего тред (пустая строка, если тред только
отклонён и код не менялся).

## Blockers raised
<пусто | список того, что скилл вынес пользователю>
```

При каждом возобновлении (новая сессия после сжатия контекста) — сначала перечитать этот файл; не
переделывать анализ, который уже лежит строкой в `Commitments`, пока рецензент не запостил новую
активность. Переиспользовать сохранённую `Branch change model`, а не пересобирать её из полного диффа:
перечитывать только дельту с `analyzed_through_sha` — но только если `analyzed_through_sha` непуст
**и** `git merge-base --is-ancestor "<analyzed_through_sha>" HEAD` завершается успешно, то есть sha
остался предком после возможного rebase. Если sha пуст либо проверка предка не прошла — пересобрать из
полного диффа (`git diff "origin/$BASE"...HEAD`) и выставить `analyzed_through_sha` в текущий `HEAD`.

### Приоритет режима при возобновлении

`Mode` в файле состояния — авторитетный источник. Свежий вызов без флага наследует сохранённый режим;
свежий вызов с явным флагом **перекрывает** его и переписывает. Так пользователь может понизить прогон
с `auto` до обычного, просто вызвав скилл заново, но автономный прогон не понижается молча только
из-за того, что кто-то отредактировал промпт пробуждения.
