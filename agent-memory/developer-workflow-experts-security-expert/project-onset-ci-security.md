---
name: onset-ci-security
description: Onset CI security/quality automation posture — классификация проверок, Copilot-вердикты, open-source features
type: project
---

Onset CI = двухскоростной (см. docs/specs/2026-06-02-onset-devops-ci.md). Распределение security/quality проверок по триггерам.

**Per-PR required (быстро, блокирует merge):** build (Swift 6 strict + warnings-as-errors) · lint (SwiftLint strict + SwiftFormat --lint) · unit (Swift Testing) · entitlements allow/deny-list на собранном .app · no-network static-proxy (`nm`/`otool`). Цель — единицы минут.

**Per-PR required, лёгкий security:** `dependency-review-action` — единственный security-скан, работающий на pull_request и лёгкий (не пересобирает проект, в отличие от CodeQL). Условно на поддержке SPM в dependency graph — проверить на docs.github.com.

**On-push / server-side (блокирует push):** GitHub secret scanning **push protection**. Локально: gitleaks pre-commit.

**Scheduled на main + on-demand (тяжёлое, НЕ блокирует merge):** CodeQL full (weekly + push:main + workflow_dispatch) — пересобирает проект, отсюда 20-30 мин → убран с PR-пути (прямой ответ на боль владельца). Copilot Autofix scan тоже сюда.

**On-merge-to-main / on-demand (не блокирует, настоящий gate — локальная L5):** L5 hardware-приёмка на self-hosted (M3 Max per-task, M1 Air финал MVP). Триггеры только dispatch/main/label — НИКОГДА fork-PR.

**On-tag:** notarization (release.yml) + опц. SBOM/provenance (`actions/attest-build-provenance`).

**Copilot-вердикты (контекст: agent-driven, код+ревью уже делают наши агенты):**
- **coding agent → SKIP (MVP).** Второй автономный автор конфликтует с принципом 15 + race на issues + auto-merge. Не нужна вторая независимая автор-система.
- **autofix → LATER/caution**, условно на поддержке Swift у Copilot Autofix (CodeQL Swift = GA, но coverage Autofix у́же — проверить docs.github.com). Его PR — через обычный required-гейт + agent-review, НИКОГДА blind auto-merge.
- **code review → caution, non-blocking, optional.** Не делать required (убьёт fast-gate). Дополняет `/finalize` loop, не заменяет.
- **chat → YES, on-demand.** Безвреден.

**Why:** боль владельца — CodeQL 20-30 мин простоя на PR; agent-driven нужен fast feedback. Open-source → Actions-минуты бесплатны (билинг не констрейнт), но wall-clock простой агента важен.

**How to apply:** тяжёлое держать scheduled/on-demand с blocks_merge=false; не добавлять required-проверки в быстрый гейт без явной нужды. См. [[onset-threat-model]].
