Ссылается из: `~/.claude/skills/write-plan/references/test-plan.md` (§Расписка).

# Формат расписки тест-плана

Вместе с постоянным документом выпускается **расписка** в `swarm-report/<slug>-test-plan.md`, которую
читают потребители ниже по потоку (`multiexpert-review`, `/acceptance`) для гейтинга по расписке.

Источник истины — постоянный файл. Расписка это метаданные плюс указатель. Имена полей английские: их
парсят YAML-потребители.

Формат расписки:

```markdown
---
name: test-plan-receipt
description: Test plan artifact for <slug>
slug: <slug>
type: test-plan-receipt
status: Draft
permanent_path: docs/testplans/<slug>-test-plan.md
source_spec: <путь к спеке, если она есть, либо "inline spec">
review_verdict: pending
review_warnings: []            # заполняет multiexpert-review на WARN — список коротких строк
review_blockers: []            # заполняет multiexpert-review на FAIL — список коротких строк
phase_coverage: [Phase 1, Phase 2, ...]
platform: []                   # необязательно; наследуется из поля `platform:` исходной спеки, если оно есть.
                               # Питает генерацию TC с учётом платформы и проверки приёмки ниже по потоку
                               # (например, пропустить мобильные TC на чисто бэкендовой цели). Оставить
                               # пустым, если спека его не задала: приёмка откатится на свою эвристику.
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Test Plan Receipt: <slug>

**Status:** <статус>
**Permanent artifact:** [`docs/testplans/<slug>-test-plan.md`](../docs/testplans/<slug>-test-plan.md)
**Source spec:** <путь или описание>
**Review verdict:** <вердикт>
```

## Конвенции полей

- `status`: `Draft` сразу после генерации; `Ready` после того, как `multiexpert-review` вернул PASS
  или WARN; `Approved`, когда пользователь явно согласовал; `Mounted`, когда взят написанный
  пользователем постоянный файл без перегенерации.
- `review_verdict`: `pending` при создании; обновляется `multiexpert-review` до `PASS | WARN | FAIL`;
  `skipped` при монтировании, когда ревью не проводилось.
- `review_warnings` и `review_blockers`: массивы коротких строк, заполняемые `multiexpert-review`.
  `review_warnings` пишется на вердикт WARN (нарушены пункты d или e чеклиста — не блокирующие),
  `review_blockers` — на FAIL (нарушены a, b или c, переход к реализации заблокирован). На PASS,
  `pending` и `skipped` оба остаются пустыми массивами. Frontmatter — единственный источник истины по
  находкам ревью: тело расписки их не перечисляет заново, чтобы YAML-парсеры ниже по потоку
  оставались авторитетными.
- `phase_coverage`: список меток фаз, присутствующих в постоянном файле. Пустой список, если фича не
  разбита на фазы.
- `created` и `updated`: даты в ISO (`YYYY-MM-DD`). `updated` обязано меняться всякий раз, когда
  изменился постоянный файл либо любое поле расписки.
- Относительный путь в markdown-ссылке предполагает обычную раскладку, где `swarm-report/` и `docs/`
  лежат рядом в корне репозитория.

## Уже существующие файлы

Тест-планы, написанные до этой конвенции, и те, что появились, когда `generate-test-plan` ещё работал
отдельным скиллом, автоматически **не** мигрируются: они остаются читаемыми, но логика монтирования
совпадает только с точным путём `docs/testplans/<slug>-test-plan.md`. План, чьё имя файла не несёт
слаг, `/acceptance` смонтирует только после переименования.

Постоянный файл без расписки — это ветка `test_plan_source: mounted`, а не ошибка: mount-расписку
`/acceptance` пишет сам.
