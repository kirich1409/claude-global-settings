# QA & Testing Rules

Project-wide rules for testing decisions. Applies to all projects regardless of stack.

## 0. Mandatory testing strategy

For every task that modifies code, a testing strategy is defined during planning. It specifies what pyramid levels are applied and what tools are used. Skipping requires a strong justification (e.g. "no code modified, only markdown"). Weak justifications ("simple", "quick fix", "obvious") are not accepted.

### Verification pyramid

**Build gate (prerequisite):** the project must compile before any other verification.

**Pyramid levels — strictly sequential. Each level requires the previous to pass:**

| Level | Name | Description |
|---|---|---|
| L1 | Static analysis | lint, type check, code review, dependency audit. Always applied. |
| L2 | Unit tests | fast, no device, pure logic |
| L3 | UI tests | automated, require emulator/device |
| L4 | E2E tests | full automated flow |
| L5 | Manual verification | mobile MCP / `manual-tester`, real interaction with the running app |

Strategy always starts at L1. Moving up requires justification.

**L5 is mandatory for:** library version bumps (even patch), technology or framework migrations, infrastructure layer changes (network, storage, auth, DI), and any task described as "shouldn't affect behavior" — the claim must be verified at runtime, not assumed.

## 1. Public-API coverage gate

When code modifies a public symbol, a test must exercise it. "Public" means: Kotlin without `@internal`/`private`, Swift `public`/`open`, TypeScript `export`. Every other definition is internal until proven otherwise.

**Trivial-no-test allow-list** (gate passes without a test):
- Pure data carriers — `data class`, Swift `struct` with stored props only, TS interfaces, enums, type aliases.
- Builder DSLs that hold no logic.
- Public types that re-export an already-tested symbol.

**Test-matching rules** (in priority order):
1. File-name pattern — `Foo.kt` ↔ `FooTest.kt` / `FooTests.swift` / `Foo.test.ts`.
2. Substring match — symbol name appears in any test file inside the same module.
3. Annotation — explicit marker (`@CoveredBy("FooIntegrationTest")` or equivalent project-defined marker) referencing the test class.

If none of the above resolves to a test that touches the symbol, the gate fails — write a test or annotate as trivial before the change can pass `/check`.

## 2. Test priority framework

When planning tests, classify each case into one of:

- **P0 — release-critical.** A failure here blocks release. Crash paths, data-loss paths, security checks, payment, auth.
- **P1 — acceptance-criteria-driven.** Each AC-N from the spec maps to one P1 test case. If the spec says "given X then Y", there is a P1 case named after that AC.
- **P2 — happy path.** The single most common successful flow per surface.
- **P3 — edges.** Boundary values, empty inputs, locale/timezone, large inputs, race conditions.

P4 (cosmetic, exploratory) is excluded from formal plans and lives in `bug-hunt`-style exploration only.

## 3. Non-UI test plan trigger

A formal test plan can be lightweight when **all three** hold:
- No mockups (Figma, screenshots, wireframes) exist for the surface.
- The surface is API / library / CLI — there is no end-user UI to acceptance-test.
- A `ux-expert` review is not in scope.

In that case, drop the standard mockup-driven sections and produce a **lightweight plan** covering only:
- Input validation (types, ranges, malformed inputs).
- State transitions (which input triggers which observable state change).
- Error paths (which exception classes / error codes are emitted, when).

Skip viewport, accessibility, and visual-regression sections — they don't apply.

## 4. Author fixes broken tests in the same run — non-negotiable

The author of a change that breaks existing tests fixes those tests in the same PR. **`@Ignore` / `xit` / `t.Skip` is forbidden without a fixed follow-up issue link in the annotation.** No "merge red", no "TODO fix later", no `--skip-test-fix`. `/check` is the merge gate.

The only escape hatch is an explicit, justified skip marker that names a tracker issue: `@Ignore("flaky on iOS 17 — JIRA-1234")`. A skip without a tracked issue is a hook violation.

## 5. Test infrastructure detection markers

Detect the test runner from these marker files at repo root, in priority order:

| Marker | Stack | Default test command |
|---|---|---|
| `build.gradle*`, `libs.versions.toml`, `settings.gradle*` | JVM / Android / KMP | `./gradlew test` (`testDebugUnitTest` for Android) |
| `Package.swift` | Swift SPM | `swift test` |
| `*.xcodeproj`, `*.xcworkspace` | Xcode | `xcodebuild test` — escalate: needs explicit scheme + destination |
| `package.json` | Node | read `scripts.test`; fallback to `npm test` |
| `pyproject.toml` | Python | derive from `[tool.pytest.ini_options]` / `[tool.poetry]`; fallback `pytest` |
| `Cargo.toml` | Rust | `cargo test` |
| `go.mod` | Go | `go test ./...` |
| `Makefile` with `test:` target | Any | `make test` |

**Escalations** (block until resolved by the user):
- Xcode — never guess the scheme; if no `.xcscheme` is conventional, ask.
- Python — derive runner config; do not invent flags.
- Multiple markers in same repo (monorepo) — pick the one that owns the changed files; ask if ambiguous.
