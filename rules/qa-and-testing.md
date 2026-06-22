# QA & Testing Rules

Project-wide testing decisions, all stacks.

## 0. Mandatory testing strategy

Every code-modifying task defines a testing strategy at planning time — which pyramid levels apply, which tools. Skipping needs a strong reason ("no code, markdown only"); "simple" / "quick fix" / "obvious" are rejected.

### Verification pyramid

Levels are strictly sequential — each requires the previous to pass. Start at L0; moving up needs justification.

| Level | Name | Description |
|---|---|---|
| L0 | Build | the project — or just the necessary part (the relevant app/module, not always the whole repo) — compiles. Without this, going further is pointless. |
| L1 | Static analysis | lint, type check, code review, dependency audit — always applied |
| L2 | Unit tests | fast, no device, pure logic |
| L3 | UI tests | automated, need emulator/device |
| L4 | E2E tests | full automated flow |
| L5 | Manual verification | mobile MCP / `manual-tester` on the running app |

**L5 mandatory for:** library version bumps (even patch), tech/framework migrations, infra-layer changes (network, storage, auth, DI), any "shouldn't affect behavior" task — verify at runtime, don't assume.

**L5 — close it yourself, autonomously.** Not "for the user to run." Drive the app via mobile MCP (`mcp__mobile__*`) / `manual-tester` on an emulator/simulator **by default**; physical device only when the change needs real hardware an emulator can't reproduce (biometric HAL, camera, NFC, GPS, sensor fusion). Check availability empirically (`adb devices -l`, `emulator -list-avds`, `xcrun simctl list`) — never declare L5 infeasible from theory; if a needed AVD/image isn't installed but is easy to get, install and run. Build/install the APK yourself, drive the flow, emulate inputs. User involvement is **last resort** — only genuine walls: credentials you can't obtain, a backend on a closed/VPN network you're not on, or behavior that exists only on physical hardware.

### L5 log capture — filter, scope, redact

When L5 reads runtime logs of the app under test (logcat / `os_log` / server logs) as a verification signal, three rules are non-negotiable:

- **Anchor on a deterministic verifier, not the log text.** pass/fail comes from a test exit code, build result, or screenshot/`assert_visible`. The log is a *diagnostic hypothesis* that explains **why** — never the sole pass/fail signal (logs are noisy and flaky). Crash scan complements the deterministic check, it does not replace it.
- **Filter and scope before ingesting into context.** Never pipe raw logs into the conversation — it overflows context and buries signal in noise. Level ≥ ERROR for the pass/fail scan; scope by package/PID on Android (`--pid=$(adb shell pidof -s PKG)`, `get_logs(level="E", package=…)`), by `subsystem` on iOS (`simctl log show --predicate 'subsystem=="<bundleId>"'`); cap volume (`-m N` / `tail` / last-N); large output → a file or `ctx_batch_execute`, agent reads the path, not the bytes. Crash patterns: Android `FATAL EXCEPTION` / `AndroidRuntime: FATAL` / ANR / unhandled NPE; iOS `fault`/`error`.
- **Redact secrets before injection.** Logs the agent *reads* are bound by the same "what never goes into a log" rule as logs it writes ([[logging]]): never feed raw `.env`, `curl -v`, or `Authorization` headers into context; mask `Bearer .*`, `*_TOKEN`, `*_KEY`, PII. OWASP LLM06 — captured logs reach the model provider.

### Disposable verification tests

Tests don't have to be permanent. To confirm a migration or a one-off / temporary behavior at implementation time, it is valid to **write a test, run it (confirm it actually passes green), then delete it** — verification without committing the test. Distinct from §4: §4 forbids skipping or deleting tests you *broke* (others' coverage); a disposable test is scaffolding you authored and own. Keep a test permanent when the behavior deserves ongoing coverage; use a disposable one when the check is genuinely one-off.

## 1. Public-API coverage gate

A modified public symbol must be exercised by a test. "Public" = Kotlin without `@internal`/`private`, Swift `public`/`open`, TS `export`; everything else is internal.

**Trivial — no test needed:** pure data carriers (`data class`, Swift `struct` with only stored props, TS interfaces, enums, type aliases); builder DSLs with no logic; types re-exporting an already-tested symbol.

**No behavior change → no new test.** A pure file move/rename, repackaging, relocating a symbol, or import-only edit is **not** "modifying" the symbol — existing tests + a green build already cover it. Never add unit tests on top of a no-logic move; that is over-testing, the same noise as over-editing. The gate triggers on changed behavior or signature, not on a symbol merely changing location.

**Test-matching (priority order):** (1) file-name `Foo.kt` ↔ `FooTest.kt` / `FooTests.swift` / `Foo.test.ts`; (2) symbol name appears in any test file in the same module; (3) explicit annotation (`@CoveredBy("...")`). None resolves → gate fails: write a test or annotate trivial before `/check` passes.

## 2. Test priority framework

Classify each case: **P0** release-critical (crash, data-loss, security, payment, auth — failure blocks release); **P1** AC-driven (one test per AC-N from the spec, named after that AC); **P2** happy path (one most-common success flow per surface); **P3** edges (boundaries, empty, locale/timezone, large inputs, races). P4 (cosmetic/exploratory) excluded from formal plans — `bug-hunt` only.

## 3. Non-UI lightweight test plan

When **all three** hold — no mockups exist, the surface is API/library/CLI (no end-user UI), no `ux-expert` review in scope — drop mockup-driven sections and cover only: input validation (types, ranges, malformed), state transitions (input → observable change), error paths (which exception/error code, when). Skip viewport / accessibility / visual-regression.

## 4. Author fixes broken tests in the same run — non-negotiable

Whoever breaks existing tests fixes them in the same PR. `@Ignore` / `xit` / `t.Skip` **forbidden** without a tracked-issue link in the annotation (`@Ignore("flaky on iOS 17 — JIRA-1234")`). No "merge red", no "fix later", no `--skip-test-fix`. `/check` is the gate; a skip without a tracked issue is a hook violation.

## 5. Test infrastructure — project-defined

The concrete runner, task names, and commands are the **project's** responsibility — read them from the project's own instructions (`<repo>/CLAUDE.md`) or build config, not from a universal table here. If the project doesn't specify, infer from root marker files (`build.gradle*` / `Package.swift` / `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` / `Makefile`) plus the build config — and **block and ask** wherever a guess would be wrong: Xcode scheme/destination, Python runner flags, which module owns the changed files in a monorepo.

## 6. Verification source of truth

A mandatory planning output — defines "done", the contract `/acceptance` verifies against.

| Type | Use when | Artifact |
|---|---|---|
| Task / requirements | explicit AC or clear task | plan notes / AC list |
| Spec | too large to hold in head; traceable ACs | `/write-spec` → `docs/specs/<slug>-spec.md` |
| Test plan | structured executable cases | `/generate-test-plan` → `docs/testplans/<slug>-test-plan.md` |
| Design mockups | UI/UX visual ACs | Figma in spec `design.figma`, or screenshots |
| Debug artifact | bug-fix only — repro steps are the contract | `swarm-report/<slug>-debug.md` |
| Behavioral baseline | migration / "shouldn't affect behavior" | captured before changes (see [[task-types]] § Before-state baseline) |

**Behavioral baseline:** for "shouldn't affect behavior" / "migrate without breaking" the before-state IS the truth. Full definition — what qualifies, what does not, the test-coverage shortcut — lives in [[task-types]] § Before-state baseline (single source). In short: capture before any change (screenshots / `manual-tester` session / `e2e-scenario.md`), save to `swarm-report/<slug>-baseline.md`, then `/acceptance` verifies after-state matches 1:1. "should be fine" is not a source of truth.

**Absent source:** if none exists and creating one isn't feasible, document in the plan: intended behavior (one paragraph), why no formal source, what proxy is used (e.g. manual walkthrough vs task description). `/acceptance` Step 1.5 blocks when no source is found and proposes the upstream skill; the justification supplies the proxy — it does not bypass the gate.
