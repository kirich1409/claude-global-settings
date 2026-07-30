# Шаблоны промптов делегирования

Reference для фазы 5 скилла `cover-with-tests` — точка входа в `../SKILL.md`.

Взять шаблон под агента, выбранного маршрутизацией фазы 5, и заполнить плейсхолдеры `{…}` из фаз 1–4.
Заголовки разделов оставлять ровно как написано: по ним агент находит слоты.

Тела промптов остаются английскими — они уходят агенту дословно, и последняя строка каждого сама велит
отвечать на языке запроса пользователя.

Каждый промпт делегирования обязан нести:

1. **Пути целевого кода** — полные пути к файлам, которые покрываются.
2. **Test Infrastructure Summary** — из фазы 4.
3. **Что писать** — решения фазы 3: поведения, виды и уровни.
4. **Образцы существующих проверок** — путь к одному-двум репрезентативным файлам для стиля.
   Существующих проверок нет (строим с нуля) — поставить в слот:
   `"No example available — infer conventions from build config and project naming."`
5. **Источник истины** — путь к тест-плану или спеке из фазы 2, либо пометка о характеризации.
6. **Сценарий регрессии** — только в режиме `--regression`: структурированное описание бага из
   входных данных. В остальных режимах опустить либо поставить «N/A».

Стека без профильного агента шаблоны ниже не покрывают: там главная сессия пишет проверки сама, взяв
тот же Summary как собственный бриф.

## Шаблон для kotlin-engineer

```
Write unit tests for the following code. Match the project's existing test conventions exactly.

## Target code
Read these files:
{list of file paths}

## Test Infrastructure
{Test Infrastructure Summary}

## Regression scenario (--regression only — omit or "N/A" otherwise)
{regression_scenario: root cause + reproduction steps + expected vs actual behavior}

## Test cases to write
{decisions: behaviors, kinds, levels}

## Style reference
Read this existing test for style and conventions: {path to example test}

## Source of truth (optional)
{path to test plan from docs/testplans/, or "Characterization — pin current behavior"}

## Requirements
- Write complete, compilable test files — no TODOs, no placeholders
- Follow the project's existing naming, assertion, and setup conventions exactly
- Use the same mocking approach as existing tests (MockK/Mockito-Kotlin/fakes)
- Cover happy path, edge cases, and error paths as specified in the test case list
- Place test files in the correct test source set and package
- Each test function tests exactly one behavior
- Test names describe the behavior being verified, not the implementation
- IF a regression scenario is set: write EXACTLY ONE test for it — do NOT sweep for other
  coverage gaps; add a one-line comment on the test function:
  `// Regression: verifies fix for [root cause]`

Respond in the same language as the user's request.
```

## Шаблон для compose-developer

```
Write Compose UI tests for the following composables. Match the project's existing test conventions.

## Target composables
Read these files:
{list of file paths}

## Test Infrastructure
{Test Infrastructure Summary}

## Regression scenario (--regression only — omit or "N/A" otherwise)
{regression_scenario: root cause + reproduction steps + expected vs actual behavior}

## Test cases to write
{decisions: behaviors, kinds, levels}

## Style reference
Read this existing test for style and conventions: {path to example test}

## Source of truth (optional)
{path to test plan from docs/testplans/, or "Characterization — pin current behavior"}

## Requirements
- Use createComposeRule() or createAndroidComposeRule() as used in existing tests
- Test UI state rendering, user interactions, and state changes
- Use semantic matchers (onNodeWithText, onNodeWithTag) over implementation details
- Write complete, compilable test files — no TODOs, no placeholders
- Follow the project's existing conventions exactly
- IF a regression scenario is set: write EXACTLY ONE test for it — do NOT sweep for other
  coverage gaps; add a one-line comment on the test function:
  `// Regression: verifies fix for [root cause]`

Respond in the same language as the user's request.
```

## Шаблон для swift-engineer

```
Write unit tests for the following Swift code. Match the project's existing test conventions exactly.

## Target code
Read these files:
{list of file paths}

## Test Infrastructure
{Test Infrastructure Summary}

## Regression scenario (--regression only — omit or "N/A" otherwise)
{regression_scenario: root cause + reproduction steps + expected vs actual behavior}

## Test cases to write
{decisions: behaviors, kinds, levels}

## Style reference
Read this existing test for style and conventions: {path to example test}

## Source of truth (optional)
{path to test plan from docs/testplans/, or "Characterization — pin current behavior"}

## Requirements
- Write complete, compilable test files — no TODOs, no placeholders
- Follow the project's existing naming and structure conventions (Swift Testing `@Test` / `@Suite`
  vs XCTest `XCTestCase`) — do not mix the two in the same file
- Use the project's existing test-double approach (protocol-backed fakes, stubs, spies); do not
  introduce a new mocking library
- Cover happy path, edge cases, and error paths as specified in the test case list
- Place test files in the correct test target / Tests directory and module namespace
- For async code use `async` tests and structured concurrency; avoid `DispatchSemaphore` hacks
- Each test function tests exactly one behavior; names describe behavior, not implementation
- IF a regression scenario is set: write EXACTLY ONE test for it — do NOT sweep for other
  coverage gaps; add a one-line comment on the test function:
  `// Regression: verifies fix for [root cause]`

Respond in the same language as the user's request.
```

## Шаблон для swiftui-developer

```
Write SwiftUI UI tests for the following views. Match the project's existing test conventions.

## Target views
Read these files:
{list of file paths}

## Test Infrastructure
{Test Infrastructure Summary}

## Regression scenario (--regression only — omit or "N/A" otherwise)
{regression_scenario: root cause + reproduction steps + expected vs actual behavior}

## Test cases to write
{decisions: behaviors, kinds, levels}

## Style reference
Read this existing test for style and conventions: {path to example test}

## Source of truth (optional)
{path to test plan from docs/testplans/, or "Characterization — pin current behavior"}

## Requirements
- Match the project's existing approach — ViewInspector-style unit tests, XCUITest UI tests,
  or snapshot tests — do not introduce a new UI-testing library
- Test view state rendering, user interactions, and state changes
- Prefer accessibility identifiers / labels over view-tree internals for queries
- Write complete, compilable test files — no TODOs, no placeholders
- Follow the project's existing conventions exactly
- IF a regression scenario is set: write EXACTLY ONE test for it — do NOT sweep for other
  coverage gaps; add a one-line comment on the test function:
  `// Regression: verifies fix for [root cause]`

Respond in the same language as the user's request.
```
