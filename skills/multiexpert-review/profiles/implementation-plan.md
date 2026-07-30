---
name: implementation-plan
description: Default profile for implementation plans (Plan Mode output, plan.md files, conversation-described plans). Verdict alphabet PASS/CONDITIONAL/FAIL. Agents selected by tech-match from plan content.

detect:
  frontmatter_type: [implementation-plan, plan]
  path_globs:
    - "docs/plans/**/plan.md"
  structural_signatures: []

reviewer_roster:
  primary: []
  optional_if: []

allow_single_reviewer: true

verdicts: [PASS, CONDITIONAL, FAIL]

source_routing:
  plan_mode: EnterPlanMode
  file: edit-in-place
  conversation: inline-revise

receipt:
  path_template: "docs/plans/<slug>/plan.md"
  fields_to_update: [review_verdict, review_blockers]
---

## Rubric

Разделы `## Rubric` и `## Prompt augmentation` остаются английскими: они уходят рецензентам дословно
как дополнение промпта.

Generic implementation-plan assessment. Each reviewer applies their expertise:

- Scope of changes clearly described
- Architectural fit — modules, layers, dependency direction
- Technical approach sufficient for implementation without further questions
- Risks named and addressed
- Trade-offs surfaced where multiple valid approaches exist
- Dependencies (code, libraries, services) identified
- Testing approach outlined (if implementation includes test code)
- Verification & Sources present — the source(s) of truth that define "done" are named, collected,
  and sufficient to verify the finished change; testing strategy (pyramid levels) stated

No fixed severity mapping — reviewers judge severity from their expertise.

## Prompt augmentation

**Adversarial stance (strict but fair).** You are a red-team critic, not an approver. The agent that
wrote this plan had an incentive to pass review quickly; your job is to find what is *wrong* before
it reaches implementation. Do not reward plausible-looking prose. Equally, do not invent blockers to
look thorough — every finding must name the weakness, where it is, and why it matters.

**Anti-gaming rubric — flag these as blockers/majors:**

- **Hand-waving verbs** — "handle errors appropriately", "wire it up", "update the relevant files",
  "as needed" with no concrete file/contract/behaviour. Demand the specifics.
- **Unfalsifiable acceptance** — a task `check` a human must judge ("looks right", "works well").
  Demand a test name, grep, or build target.
- **Missing failure modes** — happy-path-only design. Demand the error / edge / empty / concurrent
  cases the change can actually hit.
- **Invisible scope** — a one-line task hiding a subsystem. Demand it be split or sized honestly.
- **Untraced requirements** — a referenced spec `AC-N` with no task that satisfies it, or a task
  satisfying nothing. Demand the mapping be complete.
- **Missing or hollow verification** — no `## Verification & Sources` section, or one that names a
  source of truth without confirming it is collected and sufficient ("baseline TBD", a
  migration/behavior-preserving task with no before-state captured), or omits the testing strategy
  (which pyramid levels apply, L5 where mandatory). Demand the concrete source, its status, and a
  sufficiency claim — a plan that can't say how the finished change is verified is not approvable.

This rubric is what converts "a plan that passes" into "a plan that is right".

## Эвристика предварительного отбора агентов

`reviewer_roster.primary` намеренно пуст. Движок откатывается на **отбор по техническому
соответствию**: просканировать содержимое плана на ключевые слова технологий, сопоставить их с
экспертизой агентов и рекомендовать двух-трёх, чьи специальности план действительно затрагивает.
Правила:

- **Совпадение по технологии** — план обязан конкретно упоминать технологии, фреймворки или слои, на
  которых агент специализируется. Общей релевантности вроде «архитектура» или «безопасность НЕ
  достаточно: `security-expert` — только когда план трогает авторизацию, шифрование, токены или
  пользовательские данные; `architecture-expert` — только когда речь о новых модулях, смене
  направления зависимостей или изменении публичного API.
- **Ценность для конкретной проблемы** — поймает ли этот агент то, чего не поймают остальные в панели?
- **Покрытие пробела** — закрывает ли он слепое пятно, которое другие рекомендованные агенты
  пропускают?

Предпочитать двух-трёх агентов, но качество важнее количества: если по-настоящему релевантен один,
рекомендовать одного — это разрешено `allow_single_reviewer: true`. `general-purpose` — запасной
вариант, только когда ни один специалист реального пробела не закрывает.

## Заметки по маршрутизации источника

- **Режим планирования** — при правке по FAIL и CONDITIONAL движок входит в режим планирования со
  списком проблем.
- **Файл** — движок правит файл плана напрямую, добавляя `## Issues to Resolve` либо перестраивая по
  месту.
- **Разговор** — движок показывает блокеры и разбирает их с пользователем инлайново.
