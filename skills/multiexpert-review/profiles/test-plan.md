---
name: test-plan
description: Profile for test-plan artifacts (docs/testplans/<slug>-test-plan.md and swarm-report/<slug>-test-plan.md receipts). Verdict alphabet PASS/WARN/FAIL with 7-item checklist (a, b, c, d, e, f, g). Primary reviewer business-analyst; adds domain specialists when spec invokes their concerns.

detect:
  frontmatter_type: [test-plan, test-plan-receipt]
  path_globs:
    - "docs/testplans/**"
    - "swarm-report/*-test-plan.md"
  structural_signatures:
    - "^## Test Cases"
    - "^#{1,6}\\s+TC-[\\w-]+"
    - "P[0-3]"

reviewer_roster:
  primary: [business-analyst]
  optional_if:
    - when: "auth|token|encryption|PII|credential"
      agent: security-expert
    - when: "SLA|latency|throughput|budget"
      agent: performance-expert
    - when: "a11y|accessibility"
      agent: ux-expert

allow_single_reviewer: true

verdicts: [PASS, WARN, FAIL]

severity_mapping:
  - items: ["a", "b", "c", "f"]
    severity: critical
  - items: ["d", "e", "g"]
    severity: major

source_routing:
  plan_mode: N/A
  file: edit-in-place
  conversation: N/A

receipt:
  path_template: "swarm-report/<slug>-test-plan.md"
  fields_to_update: [review_verdict, review_warnings, review_blockers]
---

## Rubric

Разделы `## Rubric` и `## Prompt augmentation` остаются английскими: они уходят рецензентам дословно
как дополнение промпта.

Every reviewer must evaluate the test-plan against these seven items and report the status of each one explicitly in their response. Copy the items verbatim into the review prompt so findings are comparable across agents:

- **(a) AC coverage** — every Acceptance Criterion from the linked spec has ≥1 Test Case that verifies it. Missing or weak mapping is a violation.
- **(b) Negative balance** — every happy-path (positive) TC has ≥2 unhappy/negative TCs covering the same flow (invalid input, error states, boundary violations, concurrent or race conditions). A plan that is mostly happy paths violates this item.
- **(c) Edge cases present** — at least one TC is explicitly tagged as an edge case (boundary value, empty/null, maximum size, timezone/locale boundaries, concurrency, resource exhaustion, etc.). If the plan has no edge-case TC at all, this item is violated.
- **(d) Non-functional scenarios where applicable** — if the linked spec mentions any of {SLA, latency budget, throughput, a11y, auth, encryption, PII, resource limits, rate limits}, there must be ≥1 non-functional TC covering that concern (performance, accessibility, security). Applicability is driven by spec content — if the spec mentions none of these triggers, this item is trivially satisfied.
- **(e) Priority-risk alignment** — priorities (P0–P3) are consistent with risk assessment: any high-risk flow (data loss, auth, payment, destructive actions) is at P0–P1; any user-facing critical path is at P0–P1; trivial/informational cases are at P2–P3. Mismatch between stated risk and assigned priority violates this item.
- **(f) Type field present and valid** — every Test Case declares an explicit `Type` field with a value from {`unit`, `integration`, `ui-instrumentation`, `ui-scenario`, `screenshot`, `e2e`} and a non-empty one-line `Type rationale`. A missing `Type`, an unknown value, or an empty rationale violates this item. The selection heuristic in `write-plan/references/test-plan.md` §Type is the reference; reviewers do not re-classify TCs, only check that the field exists and the rationale is plausible.
- **(g) Instrumentation declared** — when the spec / task is `user-facing` or `prod-bound`, or the feature touches an observability hot-path (network calls, payments, background jobs, auth, data migrations), the test plan ends with a `## Non-functional / Instrumentation` section that lists Log events / Metrics / Traces / Alerts / Dashboards (or sub-headings filled with concrete declarations). For internal / dev-only / pure-refactor work, an explicit `N/A: <reason>` (one line) is acceptable. A missing section, or one labelled simply `TBD` / `?` / blank, violates this item.

## Политика вердикта

| Вердикт | Триггер | Условие выхода |
|---|---|---|
| **FAIL** (блокер) | нарушен любой из пунктов **(a)**, **(b)**, **(c)**, **(f)** | план ОБЯЗАН быть переработан. Движок ведёт цикл правок до трёх циклов. После третьего всё ещё FAIL → эскалация пользователю. Конвейер заблокирован. |
| **WARN** (не блокирует) | (a), (b), (c), (f) выполнены все, но нарушен **(d)**, **(e)** либо **(g)** | конвейер продолжается. Движок записывает `review_verdict: WARN` в расписку с явным списком нарушенных пунктов. Цикл правок не требуется. |
| **PASS** (чисто) | выполнены все семь пунктов | конвейер продолжается безусловно. Движок записывает `review_verdict: PASS` в расписку. |

Одного critical от любого агента с confidence medium и выше достаточно, чтобы включить FAIL, — это
совпадает с правилами агрегации движка.

## Prompt augmentation

Every agent reviewing a test-plan receives the following 7-item checklist verbatim in their Step 3 prompt (the engine substitutes this section into `{PROFILE_PROMPT_AUGMENTATION}` literally — not by reference to the Rubric section above). Each agent must explicitly report the status of each item (satisfied / violated, with rationale). The engine parses these into the severity mapping.

---

**Test-plan rubric — evaluate each item explicitly:**

- **(a) AC coverage** — every Acceptance Criterion from the linked spec has ≥1 Test Case that verifies it. Missing or weak mapping is a violation.
- **(b) Negative balance** — every happy-path (positive) TC has ≥2 unhappy/negative TCs covering the same flow (invalid input, error states, boundary violations, concurrent or race conditions). A plan that is mostly happy paths violates this item.
- **(c) Edge cases present** — at least one TC is explicitly tagged as an edge case (boundary value, empty/null, maximum size, timezone/locale boundaries, concurrency, resource exhaustion, etc.). If the plan has no edge-case TC at all, this item is violated.
- **(d) Non-functional scenarios where applicable** — if the linked spec mentions any of {SLA, latency budget, throughput, a11y, auth, encryption, PII, resource limits, rate limits}, there must be ≥1 non-functional TC covering that concern (performance, accessibility, security). Applicability is driven by spec content — if the spec mentions none of these triggers, this item is trivially satisfied.
- **(e) Priority-risk alignment** — priorities (P0–P3) are consistent with risk assessment: any high-risk flow (data loss, auth, payment, destructive actions) is at P0–P1; any user-facing critical path is at P0–P1; trivial/informational cases are at P2–P3. Mismatch between stated risk and assigned priority violates this item.
- **(f) Type field present and valid** — every Test Case declares an explicit `Type` field with a value from {`unit`, `integration`, `ui-instrumentation`, `ui-scenario`, `screenshot`, `e2e`} and a non-empty one-line `Type rationale`. A missing `Type`, an unknown value, or an empty rationale violates this item.
- **(g) Instrumentation declared** — when the spec / task is `user-facing` or `prod-bound`, or the feature touches an observability hot-path (network calls, payments, background jobs, auth, data migrations), the test plan ends with a `## Non-functional / Instrumentation` section that lists Log events / Metrics / Traces / Alerts / Dashboards (or sub-headings filled with concrete declarations). For internal / dev-only / pure-refactor work, an explicit `N/A: <reason>` (one line) is acceptable. A missing section, or one labelled simply `TBD` / `?` / blank, violates this item.

For every Issue you raise, use the item ID as the title stem — e.g. `(a) AC coverage: API X has no test case`. This keeps synthesizer aggregation greppable.

## Работа с распиской

После синтеза на шаге 4 движок обновляет `swarm-report/<slug>-test-plan.md` — именно расписку, а не
постоянный файл в `docs/testplans/<slug>-test-plan.md`:

- `review_verdict: PASS | WARN | FAIL`;
- на WARN — список `review_warnings:` с нарушенными пунктами из `(d)`, `(e)`, `(g)` и однострочным
  обоснованием у каждого;
- на FAIL — список `review_blockers:` с нарушенными пунктами из `(a)`, `(b)`, `(c)`, `(f)`,
  блокирующей находкой и предлагаемым фиксом.

Форматом расписки владеет `write-plan/references/test-plan-receipt.md` — этот профиль пишет только три
поля, перечисленные в `receipt.fields_to_update`.

## Цикл правок (только на FAIL)

Тот же автомат состояний, что и дефолт движка: вердикт FAIL → починить план → перепрогнать ревью,
максимум три цикла. Действие «починить план» правит постоянный файл тест-плана в
`docs/testplans/<slug>-test-plan.md`. Каждый цикл дописывает в `Verdict History` файла состояния новый
вердикт и оставшиеся блокеры.
