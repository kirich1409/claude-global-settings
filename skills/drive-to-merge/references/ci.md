# drive-to-merge — обработка CI в фазе 2.2

Разобраться в упавших проверках, классифицировать, перезапустить инфраструктурные флейки и передать
строки с правками кода в делегирование фазы 3.

## Разрешить id упавшего workflow-прогона (GitHub)

Узлы `statusCheckRollup` отдают `detailsUrl` вида
`https://<host>/<owner>/<repo>/actions/runs/<RUN_ID>/job/<JOB_ID>` для проверок GitHub Actions.
Разбирать его напрямую:

```bash
# Взять первую упавшую проверку из statusCheckRollup
FAILED_CHECK=$(jq -r '
  .statusCheckRollup[]
  | select(.conclusion=="FAILURE" or .conclusion=="CANCELLED" or .conclusion=="TIMED_OUT")
  | {name, conclusion, detailsUrl}
' <<<"$PR_INFO" | jq -s 'first')

DETAILS_URL=$(jq -r '.detailsUrl // empty' <<<"$FAILED_CHECK")
RUN_ID=$(echo "$DETAILS_URL" | sed -E 's#.*/runs/([0-9]+).*#\1#')

# Откат, когда detailsUrl не подходит под шаблон /actions/runs/
# (сторонние проверки через Checks API либо проверка, чей detailsUrl ведёт в другое место):
if ! [[ "$RUN_ID" =~ ^[0-9]+$ ]]; then
  RUN_ID=$(gh run list --branch "$HEAD" --limit 20 \
    --json databaseId,headSha,conclusion \
    --jq '[.[] | select(.headSha=="'"$(git rev-parse HEAD)"'") | select(.conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out")][0].databaseId // empty')
fi

# Всё ещё пусто — это проверка не из Actions (внешний статус). Вынести пользователю
# блокером: скачивать логи произвольных внешних провайдеров скилл не умеет.
```

Для GitLab: `glab ci view` по id пайплайна из `MR_INFO.head_pipeline.id`, либо
`glab api "/projects/$PROJECT/pipelines/<pipeline_id>/jobs"` для перечисления джобов и
`glab api "/projects/$PROJECT/jobs/<job_id>/trace"` для вытягивания лога конкретного джоба.

## Поток по каждой проверке

Для каждой упавшей проверки, когда `RUN_ID` разрешён:

1. Скачать лог джоба:
   - GitHub: `gh run view --log-failed "$RUN_ID"`
   - GitLab: `glab ci trace` по id конкретного джоба.
2. Классифицировать падение:
   - падение теста → симптом плюс путь упавшего теста;
   - падение сборки → файл плюс ошибка;
   - линт или форматирование → конкретное правило;
   - инфраструктура, раннер, сеть → перезапускаемо без изменения кода.
3. Нарисовать в сессии **таблицу падений CI**:

   ```
   | Check | Failure | Likely cause | Proposed action | Delegate |
   |-------|---------|--------------|-----------------|----------|
   | build | unresolved reference: Foo | переименован класс, импорт устарел | обновить импорт в <file:line> | implement |
   | test  | ExpectedFooTest.bar assert | изменение поведения в диффе | сверить дифф с ожиданием теста | debug |
   | lint  | ktlint wrapping            | автопочинимо                | прогнать `ktlint --format` | implement |
   | e2e   | network timeout            | флейк                       | перезапустить один раз     | — |
   ```

4. Инфраструктурные флейки перезапускать один раз автоматически
   (`gh run rerun "$RUN_ID" --failed`). Настоящие падения не перезапускать.
5. Строки с правками кода — делегировать по протоколу из [`delegation.md`](delegation.md), §Фаза 3.
6. Когда фиксы сели: запушить и войти в фазу 2.1.

## Защита от петли падений

Если одна и та же проверка падает три раунда подряд без новой диагностики по коммиту (та же сигнатура
ошибки) — остановиться и вынести блокером. Записать в `Blockers raised` файла состояния и спросить
пользователя, что делать.
