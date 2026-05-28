---
name: issue-orchestrator-design-2026-05
description: Архитектурная рекомендация для capability "issue orchestrator" в developer-workflow — форм-фактор, разрешение orchestrator-of-orchestrators, state-модель, gates, adapter
metadata:
  type: project
---

Анализ форм-фактора для "issue orchestrator" capability (ingest issues по ссылке/команде из GitHub/GitLab/Linear, анализ межзадачных зависимостей, секвенирование, делегирование имплементации, верификация, transition статусов).

Рекомендация (2026-05): **Skill**, не subagent и не MCP-как-оркестратор.

**Why:** `drive-to-merge` — готовый proof-pattern в этом же plugin: длинный автономный loop, state-файл только для compaction-resilience, `ScheduleWakeup` для polling, делегирование правок engineer-агентам, собственный merge-gate. Issue-orchestrator = тот же паттерн на уровень выше (issues вместо review-комментариев). Skill живёт в `plugins/developer-workflow/skills/`, `disable-model-invocation: true`.

**How to apply:**
- Orchestrator-of-orchestrators = композиция, не конфликт. Skill исполняется в main-session → invoke skill = main-session оркестрирует. Bright line строже чем у drive-to-merge: НИКАКИХ Edit/Write в project source из самого orchestrator (per-issue работа слишком велика для "edit rows" исключения) — полное делегирование engineer-агентам. State-файлы в swarm-report/ разрешены (process files).
- State: dual SSoT. Tracker = authoritative для issue lifecycle (open/in-progress/review/done), transition только после read (current != target → idempotent). swarm-report/<slug>-issues-state.md = orchestration state (DAG зависимостей, per-issue phase, blocker log). Phase-маркеры = derived, на resume верифицировать против ground truth.
- Gates: batch-level plan approval (Phase 0, единственный mandatory pre-batch) + per-issue blocker-only + promotion gate (если не --auto-promote) + merge ВСЕГДА спрашивает (делегировать drive-to-merge, не переизобретать). Blocker прерывает весь batch.
- Adapter: tracker-agnostic interface (fetch_issue / list / get_dependencies / transition_status idempotent / link_pr / add_comment). GH/GL = тонкие обёртки над gh/glab (уже used by drive-to-merge/create-pr). Linear = MCP, Tier-3 soft-reference per dependency policy — работать без него для GH/GL, fail-fast если user даёт Linear URL без MCP.
- Epic handling: epic = контейнер, секвенировать sub-issues, один PR на sub-issue, epic transition когда все children merged.
- Композиция > дублирование: orchestrator ВЫЗЫВАЕТ research/write-spec/finalize/acceptance/create-pr/drive-to-merge, не реимплементирует. Нужда форкнуть логику finalize/acceptance = сигнал что нужен extension-point в самом skill, не god-skill.
