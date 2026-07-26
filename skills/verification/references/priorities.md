# Test priorities, the public-API gate, and sources of truth

## Public-API coverage gate

A changed public symbol should be exercised by a test. "Public" = Kotlin without
`@internal`/`private`, Swift `public`/`open`, TS `export`; everything else is internal.

**Trivial — no test needed:** pure data carriers (`data class`, Swift `struct` with stored
properties only, TS interfaces, enums, type aliases); builder DSLs without logic; types that
re-export an already-covered symbol.

**No behaviour change → no new test.** A pure move or rename, repackaging, relocating a
symbol, or an imports-only edit is **not** a change to the symbol; existing tests plus a
green build already cover it. Never add unit tests on top of a logic-free move — that is
redundant testing, the same noise as redundant editing. The gate fires on a change in
behaviour or signature, not on a change of location.

**Matching a test to a symbol,** in priority order: (1) filename `Foo.kt` ↔ `FooTest.kt` /
`FooTests.swift` / `Foo.test.ts`; (2) the symbol name appears in any test file in the same
module; (3) an explicit annotation (`@CoveredBy("...")`). Nothing found → write a test or
mark it trivial.

## Priority framework

Classify each case:

- **P0** release-critical: crash, data loss, security, payments, auth. A failure blocks release.
- **P1** AC-based: one test per AC-N from the spec, named after that AC.
- **P2** happy path: one common success flow per interface.
- **P3** edge cases: boundaries, empty values, locale/timezone, large input, race conditions.

P4 (cosmetic/exploratory) is excluded from formal plans — that is exploratory QA through the
`manual-tester` agent.

## Lightweight plan for non-UI surfaces

When **all three** hold — no mockups, an API/library/CLI surface (no end-user UI), no
`ux-expert` review in scope — drop the mockup-driven sections and cover only: input
validation (types, ranges, malformed data), state transitions (input → observable change),
and error paths (which exception or error code, and when). Skip viewport, accessibility, and
visual regression.

## Whoever broke a test fixes it in the same run

Broken existing tests are fixed in the same PR by whoever broke them. `@Ignore` / `xit` /
`t.Skip` require a tracked issue in the annotation (`@Ignore("flaky on iOS 17 —
JIRA-1234")`). No merging red, no "we'll fix it later", no skipping the fix. A skip without
a tracked issue is a gate violation.

## Test infrastructure is defined by the project

The specific runner, task names, and commands are the **project's** responsibility — read
them from the project's own instructions (`<repo>/CLAUDE.md`) or its build config, not from
a universal table. If the project does not say, infer from marker files at the root
(`build.gradle*` / `Package.swift` / `package.json` / `pyproject.toml` / `Cargo.toml` /
`go.mod` / `Makefile`) plus the build config — and **stop and ask** where a guess would be
wrong: Xcode scheme and destination, Python runner flags, which module owns the changed
files in a monorepo.

## Source of truth for verification

A required output of planning: it defines "done" and is the contract `acceptance` checks
against.

| Type | Use when | Artifact |
|---|---|---|
| Task / requirements | explicit AC or a clear task | plan notes / AC list |
| Specification | too large to hold in your head; trackable AC | `write-spec` → `docs/specs/<slug>-spec.md` |
| Test plan | structured executable cases | `generate-test-plan` → `docs/testplans/<slug>-test-plan.md` |
| Design mockups | visual AC for UI/UX | Figma in the spec's `design.figma`, or screenshots |
| Debug artifact | bug fixes only — the reproduction steps are the contract | `swarm-report/<slug>-debug.md` |
| Behavioural baseline | migration / "should not affect behaviour" | capture before changing anything (see `task-types.md`) |

**Missing source:** if none exists and creating one is unrealistic, document it in the plan —
the assumed behaviour in a paragraph, why there is no formal source, and what proxy is being
used (e.g. a manual walkthrough versus the task description). `acceptance` blocks when no
source is found and points at the upstream skill; the documented rationale supplies the
proxy. That is not a way around the gate.
