# Verification pyramid — levels and how to run them

## Levels

Sequential: each level assumes the one below it passes. Start at L0; going higher needs a
reason.

| Level | Name | Description |
|---|---|---|
| L0 | Build | The project — or just the relevant part (the app/module in question, not always the whole repo) — compiles. Nothing above this is meaningful without it. |
| L1 | Static analysis | Lint, typecheck, code review, dependency audit. Applies always. |
| L2 | Unit tests | Fast, no device, pure logic. |
| L3 | UI tests | Automated, needs an emulator or device. |
| L4 | E2E tests | Full automated flow. |
| L5 | Manual verification | Mobile MCP or the `manual-tester` agent against a running app. |

**L5 is mandatory for:** library version bumps (including patch), tech/framework migrations,
infra-layer changes (network, storage, auth, DI), and any task framed as "should not affect
behaviour" — check at runtime instead of assuming.

## A new guard is proven by a rejected push, not by a registered task

Adding a check, lint rule, or gate is not demonstrated by showing the task exists and is
wired into an aggregate (`check`, `verify`, a similarly named CI job). Show it actually runs
on the path that fires in anger: trigger a real violation and watch the pre-push hook or CI
reject it.

This is not hypothetical. A guard was wired into the Gradle `check` task while the pre-push
hook and CI workflow only ever invoked `ktlintCheck` and `detekt`. The guard would never
have fired once. It surfaced only by comparing the gate's actual entry points against where
it was registered.

## Run L5 yourself

Close L5 autonomously — not "let the user run it". Drive the app through mobile MCP
(`mcp__mobile__*`) when connected, otherwise `adb` / `android` CLI or `manual-tester`, on an
emulator or simulator **by default**. Use a physical device only when the change needs real
hardware an emulator cannot reproduce (biometric HAL, camera, NFC, GPS, sensor fusion).

Check availability empirically (`adb devices -l`, `emulator -list-avds`, `xcrun simctl list`)
rather than declaring L5 impossible from theory; if the needed AVD or image is missing but
easy to obtain, install it. Build and install the APK yourself, drive the flow, simulate
input.

Involve the user only as a last resort, for genuine obstacles: credentials that cannot be
obtained, a backend behind a closed network, or behaviour that exists only on physical
hardware.

## A device under L5 is exclusive, not shared

The physical device or emulator running a pass is occupied for the duration. Never run two
device-touching L5 agents against the **same** device in parallel — they overwrite each
other's APK and corrupt each other's run. This has already broken an acceptance pass: two
L5 agents on one emulator.

Either serialise device work on a single device, or give each agent its own device or AVD —
including a read-only clone of the same image (`emulator -avd <name> -read-only` brings up a
second copy without touching the primary's state, giving a clean unauthorised instance while
preserving the authorised session on the working one). With several devices attached, pass
an explicit `-s <serial>` on every adb command.

## Cost of L5 — don't burn turns on screenshots

Profiling showed acceptance runs are the most expensive tasks and the main source of
spinning: one final acceptance pass took **1540 turns at 76 output tokens per turn** — one
turn per tap, then a screenshot and a check. The cause is the device-driving method, not the
model.

Pick the cheapest tool that answers the question:

| Question | Tool | Rough cost |
|---|---|---|
| Is the element there, what's on screen | `ui(action:'tree', format:'semantic')` | ~60 tokens |
| Interactive elements only | `ui(action:'tree', compact:true)` | ~100 |
| Find one specific element | `ui(action:'find')` | ~150 |
| Quick visual sanity check | `screen(action:'capture', preset:'low')` | ~1500 |
| Full screenshot | `screen(action:'capture')` | ~3000 |

- **Tree instead of screenshot by default.** Screenshots are for genuinely *visual* checks:
  layout, letterboxing, contrast, match against a mockup. For "did it tap", "did the item
  appear", "did the screen change" — the tree is 30-50x cheaper.
- **`flow(action:'batch')` for sequences.** One tap per turn is the main source of spinning;
  batching folds steps into a single call.
- **Diffs already come back**: input actions return a UI diff. A screenshot after every tap
  is an anti-pattern — the diff already arrived.
- **`screen(diff:true)`** after an action returns only what changed.
- Never request a tree and a screenshot together — pick one.

Screenshots are obligatory where the check is visual: comparison against a mockup, layout
regressions, before/after proof of a visual defect. Pay full price there deliberately.

## L5 log capture — filter, scope, redact

When L5 reads runtime logs (logcat, `os_log`, server logs) as a verification signal:

- **Anchor on a deterministic verifier, not log text.** Pass/fail comes from a test exit
  code, a build result, or a screenshot/`assert_visible`. The log is a *diagnostic
  hypothesis* explaining **why** — never the sole pass/fail signal, because logs are noisy
  and unstable. Crash scanning supplements the deterministic check; it does not replace it.
- **Filter and scope before it reaches context.** Never pipe raw logs into the conversation
  — it floods context and buries the signal. Use level >= ERROR for pass/fail scanning; scope
  by package/PID on Android (`--pid=$(adb shell pidof -s PKG)`, `get_logs(level="E",
  package=…)`) and by `subsystem` on iOS (`simctl log show --predicate
  'subsystem=="<bundleId>"'`); cap the volume (`-m N` / `tail` / last-N); send large output
  to a file or `ctx_batch_execute` and read the path, not the bytes. Crash patterns: Android
  `FATAL EXCEPTION` / `AndroidRuntime: FATAL` / ANR / unhandled NPE; iOS `fault` / `error`.
- **Redact secrets before they reach context.** Logs an agent *reads* obey the same rule as
  logs it writes (see `logging`): never pass raw `.env`, `curl -v`, or `Authorization`
  headers into context; mask `Bearer .*`, `*_TOKEN`, `*_KEY`, and PII. OWASP LLM06 — captured
  logs reach the model provider.

## Disposable verification tests

Tests do not have to be permanent. To confirm a migration or a one-off behaviour during
implementation it is fine to **write a test, run it, confirm it passes, then delete it** —
verification without committing the test.

This differs from the broken-test rule in `priorities.md`: that forbids skipping or deleting
tests you *broke* (someone else's coverage). A disposable test is scaffolding you wrote and
own. Keep it when the behaviour deserves permanent coverage; make it disposable when the
check genuinely is one-off.
