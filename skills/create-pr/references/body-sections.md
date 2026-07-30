# create-pr — банк разделов тела PR

Ссылается из: `~/.claude/skills/create-pr/SKILL.md` (§7.1).

Заголовки разделов остаются английскими: это то, что публикуется на платформе, и SKILL.md адресует их
этими же именами. По-русски здесь только инструкции внутри комментариев — их читает агент, а не
ревьюер PR.

Доступные разделы, включать только применимые:

```markdown
## What changed
<!-- Техническое описание из лога коммитов и диффа -->

## Why / motivation
<!-- Из описания задачи или артефакта плана; если в коммитах есть URL тикета — дать ссылку -->

## Artifacts
<!-- Список существующих путей в swarm-report/ и docs/ -->
- Plan: docs/plans/<slug>/plan.md
- Test plan: swarm-report/<slug>-test-plan.md
- ...

## How to test
<!-- Из test-plan.md либо из acceptance задач в plan/tasks.md; список чекбоксов -->
- [ ] Scenario 1
- [ ] Scenario 2

## Release Notes
<!--
  Выдаётся, когда изменение видимо пользователю (SKILL.md §7.2.1).
  Формат следует существующей конвенции changelog в проекте. Тело PR — только текст:
  НЕ править CHANGELOG.md, .changeset/, RELEASE_NOTES.md и docs/CHANGELOG.md.
  Для тела PR выбрать ОДНУ форму:

  Keep-a-Changelog (CHANGELOG.md / RELEASE_NOTES.md / docs/CHANGELOG.md):
  ### Added
  - Короткое описание для пользователя (#NNN)

  Changesets (.changeset/) — сокращение только для тела PR, НЕ настоящий формат changeset:
  type: minor
  Короткое описание для пользователя.

  (Настоящий файл .changeset/*.md использует --- frontmatter, сопоставляющий пакеты уровням
  бампа; этот сниппет в теле PR нужен лишь для видимости во время ревью.)

  Changelog в проекте ещё нет — обычный пункт:
  - **<Область>:** короткое описание для пользователя.

  Маркер ломающего изменения (в любом формате):
  **Breaking:** что пользователям нужно сделать, чтобы мигрировать.

  Когда раздел намеренно пропущен:
  > Release notes: skipped (<причина>)
-->

## Status
<!-- Таблица: стадии реализации и приёмки, pass/fail/pending из артефактов -->
| Stage | Result | Notes |
|---|---|---|
| Implement | ✅ PASS | all gates green |
| Acceptance | ⏸ pending | waits for implement |

## Screenshots / demo
<!-- Для визуальных изменений; запросить у пользователя -->

## Checklist
- [ ] Tests added or updated
- [ ] No breaking changes (or documented)
- [ ] Relevant docs updated

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
