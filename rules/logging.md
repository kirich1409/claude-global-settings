# Logging

Two modes of logging coexist in the codebase and must not be mixed up:

- **Permanent logs** — part of the product, ship to production, help debug live incidents.
- **Temporary diagnostic logs** — added during local investigation, removed before the change is finalized.

Both modes are allowed and encouraged. What is forbidden is ad-hoc `println` / `console.log` / `print()` / `System.out` / `NSLog` — see *Logger system* below.

## Logger system — mandatory

All logging goes through the project's logger framework. Never write `println`, `System.out.println`, `print()`, `console.log`, `console.debug`, `NSLog`, `fmt.Println` for diagnostic or operational output. If the project does not have a logger configured yet — set one up first; that itself is part of the task.

Defaults per stack (use the one already in the project; otherwise propose during planning):

| Stack | Default logger |
|---|---|
| Android | Timber, or `android.util.Log` if Timber not present |
| JVM / Kotlin server | `slf4j` (`KotlinLogging` wrapper) |
| KMP shared | `co.touchlab.kermit` |
| iOS / Swift | `os.Logger` (Unified Logging) |
| Node / TS | project logger (`pino`, `winston`, `bunyan`); never `console.*` |
| Python | `logging` stdlib; never `print` |
| Go | project logger (`slog`, `zap`, `zerolog`); never `fmt.Println` |
| Rust | `tracing` / `log`; never `println!` |

User-facing CLI output (`stdout` for the actual program result) is not logging and is exempt.

## Permanent logs — write them generously

Permanent logs are allowed at every level. They are not "noise to be minimized" — they are a debugging asset. Add them whenever they make future investigation cheaper.

Good targets:
- Inputs and outputs at system boundaries (HTTP request/response, DB query/result, IPC, file I/O).
- Errors with full context (what was attempted, with which inputs, what was the failure).
- Key state transitions (auth state changes, session start/end, screen lifecycle, feature flag evaluation).
- Decision points where the code branches on non-obvious conditions.

Production safety still applies (see *What never goes into a log* below). Past that — bias toward more, not less.

Production-build stripping is part of why this is safe:
- Android R8/ProGuard removes `Log.v` / `Log.d` calls when the project's ProGuard rules include the standard `-assumenosideeffects class android.util.Log { ... }` block (or equivalent for Timber).
- Server / JVM apps configure the production log level (`info` or `warn`) so `debug` / `trace` calls are skipped at runtime with near-zero cost.
- iOS `os.Logger` `debug` is auto-filtered out of release logs by the system.

Verify the stripping mechanism is in place when adding heavy `debug` logging. If it is not — add it as a separate decision, do not silently flood production with `debug` output.

### Log-level semantics

Follow standard severity. Project conventions win if they differ.

| Level | Use for |
|---|---|
| `error` | Operation failed, user-visible or system-impacting. Always includes the exception/cause. |
| `warn` | Degraded behavior, fallback taken, retry exhausted, unexpected but recoverable input. |
| `info` | Significant lifecycle events: app start, user signed in, job scheduled, screen entered. One per real-world event, not per loop iteration. |
| `debug` | Internal state useful when investigating a bug. Stripped from release. Verbose is OK here. |
| `verbose` / `trace` | Per-iteration detail, raw payloads, fine-grained flow. Stripped from release. |

Choose the level by *who needs to see this and when*, not by how interesting the log feels at write-time.

## Temporary diagnostic logs — `// TEMP-LOG`

When investigating a bug, an unclear flow, or a failed hypothesis — instrument the code with logs to see what actually happens. This is a first-class debugging tool, not a workaround. After the second failed read-only hypothesis, instrumenting is usually faster than guessing further.

**Marking rule.** Every temporary log line gets a `// TEMP-LOG` comment on the line above (or `# TEMP-LOG` / `/* TEMP-LOG */` per language). One unique grep target, language-agnostic, survives reformatting.

```kotlin
// TEMP-LOG: investigating null state on checkout
Timber.d("order=%s, cart=%s", order, cart)

// TEMP-LOG
logger.debug { "reached checkout with $session" }
```

```swift
// TEMP-LOG: why does the cell flicker on first load
logger.debug("cell.bind id=\(id) state=\(state)")
```

```python
# TEMP-LOG
log.debug("payload=%s", payload)
```

**Lifecycle.**
1. Add `// TEMP-LOG` log → reproduce → read output → form a hypothesis.
2. Iterate as needed. Add more `// TEMP-LOG` lines freely.
3. Once the root cause is understood and the fix is in place — remove every `// TEMP-LOG` line before finalization.

**Promotion is a deliberate decision.** If during investigation it becomes clear that a `// TEMP-LOG` line is genuinely valuable in production — remove the marker comment, possibly downgrade/upgrade the level, and treat it as a permanent log under the rules above. Do not "forget to remove" the marker.

**Finalization gate.** Before `/finalize` / `/check` / opening a PR, scan the diff:

```
git diff | grep -nE 'TEMP-LOG'
rg -n 'TEMP-LOG' --no-heading
```

Any hit blocks the gate. Either remove the line, or consciously promote it (remove the marker, justify the keep).

## What never goes into a log — any mode

These are non-negotiable regardless of permanent vs temporary:

- Secrets: passwords, API keys, tokens, session cookies, signing keys, private keys.
- PII without need: full names, emails, phone numbers, addresses, document IDs. If absolutely required — log a stable hash or last-4 only.
- Payment data: full PAN, CVV, full IBAN. Last-4 of PAN is acceptable when project policy allows.
- Large blobs by default (full request bodies, full files). If needed for diagnosis — truncate with explicit `…[N bytes truncated]`.
- Anything covered by the project's privacy policy or compliance scope (GDPR, HIPAA, PCI) without an explicit allowance.

Temporary `// TEMP-LOG` lines are not an exception — the diff goes through review, and "I would have removed it" is not a defense.

## When to instrument

The "should I add logs" decision tree:

1. **Writing new code with non-trivial flow** → add permanent logs at boundaries and key transitions as you go. Not a separate step.
2. **Investigating a reproducible bug, read-only attempts are not converging** → instrument with `// TEMP-LOG`. Do not keep guessing past two failed hypotheses without instrumentation.
3. **Investigating a flake / intermittent issue** → instrument with `// TEMP-LOG` at suspected race / timing points, often at `verbose` level. Likely needs several iterations.
4. **Code review uncovers an unclear runtime path** → the right answer is usually a permanent `debug` log on the path, not a comment explaining what the code does.
