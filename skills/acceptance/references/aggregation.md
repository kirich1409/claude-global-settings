Ссылается из: `~/.claude/skills/acceptance/SKILL.md` (§Шаг 6, агрегировать и записать расписку).

# Acceptance — агрегация, формат расписки и маршрутизация

Сначала читать frontmatter каждого `swarm-report/<slug>-acceptance-<check>.md` (verdict, severity,
confidence, domain_relevance, blocked_on). Тело читать только при `verdict != PASS`. Тела артефактов
не вставлять — давать на них ссылки.

**Отсутствующий артефакт подпроверки.** Свой артефакт пишет каждая проверка, в том числе при падении:
механический блок пишет его даже на красной сборке, а пропущенная проверка пишет его с
`verdict: SKIPPED`. Если запланированный артефакт всё же отсутствует на момент агрегации, считать
проверку `verdict: FAIL` с `blocked_on: per-check artifact missing` — молча не отбрасывать. `blocked_on`
и есть каноническое поле для вынесения неразрешённых условий по схеме подпроверки; отдельного поля
`error:` не существует.

## Агрегация — правила PoLL

Приёмка использует тот же протокол агрегации, что и `multiexpert-review` (см.
`multiexpert-review/SKILL.md`, §Шаг 4). Форма входа здесь по проверкам, а не по ревьюерам; логика
свёртки идентична:

| Сигнал | Действие |
|---|---|
| **severity `critical`** от любой подпроверки с `confidence: high` | → блокер. Aggregated Status = `FAILED`. |
| **Одна и та же проблема** (тот же `file:line` либо тот же идентификатор AC) поднята двумя и более подпроверками независимо | → эскалировать до `critical` независимо от индивидуальной severity. Несколько специалистов видят одно и то же — это настоящая проблема. |
| **severity `major`** от подпроверки с `domain_relevance: high` | → важное. Aggregated Status = `PARTIAL`, если ещё не эскалировано выше. |
| **Противоречащие вердикты** (одна проверка `PASS`, другая `FAIL` по тому же пункту) | → «неопределённость, требует решения». Aggregated Status = `PARTIAL`, противоречие перечислено в расписке. |
| **severity `minor`** либо **`confidence: low`** от одной проверки | → заметка, не блокер. На сводный статус не влияет. |
| Проверка с **`domain_relevance: low`**, поднявшая проблему | → заметка, вес ниже. |

**Severity багов (P0–P3) остаётся главной осью маршрутизации** для вызывающего. Любой баг P0 или P1 от
любой подпроверки напрямую даёт `FAILED` независимо от PoLL выше; PoLL накладывает дополнительные
правила поверх — для случаев, которые severity бага сама по себе не покрывает (например FAIL по
покрытию AC без связанного бага P0).

## Aggregated Status — итоговая таблица

| Вход | Aggregated Status |
|---|---|
| Все проверки `PASS` или `SKIPPED`, багов P0–P3 нет, блокера PoLL нет | `VERIFIED` |
| Любой баг P0 или P1 **либо** блокер PoLL (critical с высокой confidence либо эскалация от двух и более агентов) | `FAILED` |
| Только баги P2 и P3, **либо** важное по PoLL, **либо** противоречащие вердикты, **либо** любой `WARN`, не классифицированный иначе | `PARTIAL` |
| `manual-tester` вернул `WARN` с `blocked_on` | `PARTIAL`, и `blocked_on` вынесен в Summary |

## Формат расписки

Сохранять в `swarm-report/<slug>-acceptance.md`. Имена полей и заголовки разделов английские: их
читают потребители ниже по потоку.

```markdown
# Acceptance: <slug>

**Status:** VERIFIED / FAILED / PARTIAL
**Date:** <дата>
**Type:** Feature / Bug fix
**Project type:** <project_type>
**Project type override:** <spec | user | none>
**Ecosystem:** <ecosystem>
**Spec source:** [что использовано]
**Test plan:** [разрешённый постоянный путь / сгенерирован на лету / нет]
**test_plan_source:** receipt | mounted | on-the-fly | absent
**Context artifacts:** [пути к вышестоящим артефактам-входам — research.md, debug.md, coverage-diagnosis.md, coverage-audit.md]
**Arguments:** [строка аргументов дословно, с причиной вызывающего на каждый сужающий флаг — либо `none`]

## Idempotency Hashes
- `diff_hash`: <sha256 от `git diff <base>...HEAD`>
- `spec_hash`: <sha256 байтов файла спеки либо `null`, если спеки-файла нет>
- `test_plan_hash`: <sha256 постоянного тест-плана либо `null`>

Эти три хеша питают таблицу решений цикла повторной верификации; оркестраторам выше их читать не нужно.

## Check Plan
- список проверок, которые отработали, по строке на каждую, с триггером
- например `business-analyst` (покрытие AC) — триггер spec.acceptance_criteria_ids
- например `ux-expert` — не сработал (нет design.figma)

## Check Results

| Check | Agent / Tool | Verdict | Severity | Confidence | Artifact |
|---|---|---|---|---|---|
| Mechanical | bash | … | … | … | swarm-report/<slug>-acceptance-mechanical.md |
| Code review | code-reviewer | … | … | … | swarm-report/<slug>-acceptance-code.md |
| Coverage | cover-with-tests | … | … | … | swarm-report/<slug>-acceptance-coverage.md |
| UI tests | bash | … | … | … | swarm-report/<slug>-acceptance-ui-tests.md |
| E2E | bash | … | … | … | swarm-report/<slug>-acceptance-e2e.md |
| Manual QA | manual-tester | … | … | … | swarm-report/<slug>-acceptance-manual.md |
| AC coverage | business-analyst | … | … | … | swarm-report/<slug>-acceptance-ac-coverage.md |
| Design | ux-expert | … | … | … | swarm-report/<slug>-acceptance-design.md |
| A11y | ux-expert | … | … | … | swarm-report/<slug>-acceptance-a11y.md |
| Security | security-expert | … | … | … | swarm-report/<slug>-acceptance-security.md |
| Performance | performance-expert | … | … | … | swarm-report/<slug>-acceptance-performance.md |
| Architecture | architecture-expert | … | … | … | swarm-report/<slug>-acceptance-architecture.md |
| Build config | build-engineer | … | … | … | swarm-report/<slug>-acceptance-build-config.md |
| DevOps | devops-expert | … | … | … | swarm-report/<slug>-acceptance-devops.md |

## Convergence signals
Проблемы, поднятые двумя и более подпроверками независимо. Сильнейший сигнал реальных дефектов.
По строке на каждую, с `file:line` либо идентификатором AC и списком проверок, которые её отметили.

## Summary
[1–3 предложения. Если PARTIAL с blocked_on — блокер первым. Если есть сигнал схождения —
упомянуть его в первом предложении.]

## Test Results
- Всего: [n] | Пройдено: [n] | Упало: [n] | Заблокировано: [n]

## Bugs Found
[По severity — сначала P0, затем P1, P2, P3. Каждый со ссылкой на артефакт подпроверки,
которая его сообщила.]

## Bug Reproduction Check (только багфикс)
- Шаги воспроизведения из debug.md: [исполнены / неприменимо]
- Баг воспроизводится после фикса: [да / нет]

## Recommendation
[Ship / Do not ship / Ship with known issues — и почему]
```

## Маршрутизация (её читают вызывающие)

- **VERIFIED** → `create-pr` либо перевод существующего PR в ready for review.
- **FAILED** с P0/P1 и очевидной причиной → починить на ветке, взяв список багов входом, и
  перепрогнать приёмку. Максимум три круга.
- **FAILED** с P0/P1 и непонятной причиной → сначала расследовать первопричину, затем чинить и
  перепрогонять.
- **FAILED** с P0/P1, требующим регрессионного покрытия → `/cover-with-tests <область> --source-of-truth=swarm-report/<slug>-debug.md`
  пишет проверку: он проверяет контракт red-green, чего приёмка не может — к моменту её запуска фикс
  уже в дереве. Затем чинить и перепрогонять.
- **GAPS_FOUND** от coverage-аудита → `/cover-with-tests` по перечисленным пробелам отдельным шагом,
  затем перепрогон. Приёмка пробел не закрывает никогда.
- **PARTIAL** только с P2/P3 либо с WARN — спросить пользователя: чинить сейчас или отгружать с
  известными проблемами (дальше в `create-pr`, с упоминанием в описании PR).
- **PARTIAL** с `blocked_on` — вынести блокер; не продолжать, пока он не разрешён.
