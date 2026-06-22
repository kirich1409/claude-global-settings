---
paths:
  - "**/*.kt"
  - "**/*.kts"
---

# Kotlin Rules

Applies to `.kt` and `.kts` files. Covers code style (visibility, collections, named arguments, empty blocks) plus project conventions a modern model omits by default — value-class validation, parameter nullability, KMP `commonMain` constraints, Clean Architecture + MVI layering. Generic idiomatic Kotlin (null safety, naming, organization) is **not** documented here; trust the model and the [official Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html).

## Visibility — minimum by default

The visibility of every declaration must be the narrowest one that still works. Always pick from this priority:

1. **`private`** — first choice. Used inside one file or one class only.
2. **`internal`** — next choice. Used across files inside the same module.
3. **`public`** — last resort. Only for declarations that are intentionally part of the module's external API surface.

Do not leave declarations at default `public` visibility "just because it compiles". Default `public` is a deliberate API decision, not a fallback.

If the project has a clearly different, established visibility convention, follow the project.

### How to apply

- **New code in feature / internal-implementation modules** (`internal/` packages, `feature/.../internal/`, anything not in `api/`) → `internal` by default. Use `private` whenever the symbol is not referenced outside its file/class.
- **Public API modules** (`api/`, exposed contracts in `:protocol/`, `:new-core/` shared infra) → `public` is acceptable, but only for declarations meant to be used by other modules. Internal helpers in these modules still go to `internal` / `private`.
- **Top-level functions, extensions, properties** — same rule. A helper used only inside one file → `private`. Used across the module → `internal`. Never make it public unless other modules need it.
- **Classes, interfaces, sealed hierarchies** — narrowest visibility wins. A sealed class implementation hierarchy used only inside the module must be `internal`.
- **Constructors** — narrow them too. If a class is instantiated only through a factory or DI, mark the constructor `internal` or `private`.
- **`companion object` members** — same priorities.
- **Don't write the `public` keyword explicitly** — it's the Kotlin default. Writing `public class Foo` is redundant; use `class Foo`. The `public` keyword adds noise and signals nothing. Reserve explicit modifiers for `internal` and `private`.

### When unsure

If you cannot decide between `internal` and `public` — pick `internal`. Widening visibility later is trivial; narrowing it later is a breaking change for anyone who already used the broader form.

### `.kts` (Gradle Kotlin DSL)

Same rule applies. Top-level helpers in convention plugins, `build.gradle.kts`, and `settings.gradle.kts` should be `private` if used only in that script, `internal` if shared inside the build module.

## Collection operations — prefer extension operators over `for` loops

For any operation over a collection / `Sequence` / `Iterable` / `Map` / `Flow`, prefer the standard-library extension operator over an imperative `for` loop. The operator name documents intent; a `for` body with `if`/`add`/`continue` hides it.

Common mappings:

- Filter → `filter` / `filterNot` / `filterIsInstance` / `filterNotNull`.
- Transform → `map` / `mapNotNull` / `mapIndexed` / `flatMap`.
- Aggregate → `sumOf` / `count` / `maxByOrNull` / `minByOrNull` / `fold` / `reduce`.
- Group / index → `groupBy` / `associateBy` / `associateWith`.
- Search → `find` / `firstOrNull` / `any` / `all` / `none`.
- Side effect over each element → `forEach` / `onEach` (use `onEach` when chaining).
- Build a collection step-by-step → `buildList` / `buildSet` / `buildMap`.

### When `for` is the right choice

Keep a `for` loop when **any** of these hold — the operator form would be worse:

- Early `return` from the enclosing function based on the loop body (cannot inline-return from `forEach` without `return@label` gymnastics).
- Multiple side effects per iteration that don't compose into a single transformation (e.g. logging + mutating two unrelated structures + checking cancellation).
- Index-and-neighbor access where `zipWithNext` / `windowed` would be less clear than direct `for (i in indices)`.
- Performance-critical hot path where allocation of intermediate collections is measurable — prefer `Sequence` / `asSequence()` first; drop to `for` only when profiled.

When in doubt, write the operator chain. If it ends up needing more than three operators or a `let`-tower, reconsider — but don't fall back to `for` mechanically.

## Named arguments — required for ambiguous calls

Use named arguments when **any** of the following hold:

- The argument is a **primitive type** (`Boolean`, `Int`, `Long`, `String`, etc.) and its meaning is not obvious from the call site alone.
- **Multiple parameters share the same type** — name every argument of that type. Other arguments in the same call may stay positional unless they fall under another rule.
- A **lone boolean literal** is the worst offender — `setVisible(true)` tells the reader nothing. Name it even when it is the only argument: `setVisible(visible = true)`.

```kotlin
// Bad — three Strings, meaning unclear
createUser("Alice", "alice@example.com", "password123")

// Good — same-type args named; positional allowed only when unambiguous
createUser(name = "Alice", email = "alice@example.com", password = "password123")

// Bad — Boolean argument with no context
setRetry(true, 3)

// Good
setRetry(enabled = true, maxAttempts = 3)
```

### When positional is fine

- Non-primitive, domain-typed argument whose type already documents the meaning: `show(dialog)`, `navigate(destination)`.
- Single-argument call where the function name makes the argument obvious: `listOf(items)`, `println(message)`, `delay(500)`. A lone **boolean** literal is never exempt — see above.
- Well-known stdlib/operator-style calls: `maxOf(a, b)`, `Pair(key, value)`.

The test: a reader who sees only the call site — not the function signature — must be able to infer what each argument means without guessing.

## Empty blocks — delete the call

If a call ends with an empty `{}` block and the call exists only to satisfy a signature, delete it. An empty lambda / `apply {}` / `run {}` / `also {}` / `let {}` / `forEach {}` carries no behaviour and obscures the fact that nothing happens.

### How to apply

- `something.apply {}` / `something.also {}` / `something.run {}` / `something.let {}` with empty body → delete the whole expression (or replace with the receiver if the value is used).
- `forEach {}` / `onEach {}` with empty body → delete; the chain has no side effect to perform.
- Empty `init {}` block in a class → delete.
- Empty `catch (e: X) {}` — **not covered by this rule**: silently swallowing exceptions is a separate concern (see error-handling). Either log/handle or remove the `try` entirely.
- Empty body required by an interface / abstract method override → keep, but add a one-line comment stating why nothing is done (`// no-op: <reason>`). Without the comment a reader cannot tell intentional from forgotten.
- Empty lambda passed as a default-callback argument (`onClick = {}`) — keep only if the API requires non-null; prefer `null` + nullable type when the API allows it.

The rule is about **calls that do nothing and mean nothing**. If the empty block expresses an intentional no-op at an API boundary, it stays — with a comment.

## Value Class Validation

Wrapping a primitive in `@JvmInline value class` is the obvious part. The non-obvious part: **add `init { require(...) }` when the wrapper enforces a constraint** — non-blank, valid format, range. The model often skips this without a reminder.

```kotlin
@JvmInline
value class Email(val value: String) {
    init { require("@" in value) { "Invalid email: $value" } }
}

@JvmInline
value class FavoriteId(val value: String) {
    init { require(value.isNotBlank()) { "FavoriteId must not be blank" } }
}
```

If the wrapped value has no real constraint (e.g. opaque server-generated ID) — skip the `init` block. Validate where validation is meaningful, not as ceremony.

## Parameter Nullability and Overloads

A nullable parameter on an extension or top-level function is a **design smell**. It usually means the responsibility for handling the absent case belongs one level up, at the call site.

- Extension and top-level functions take non-nullable receivers and parameters whenever possible — `fun String.parse()` not `fun String?.parse()`
- If a caller may have a nullable value, provide an overload or let the caller use `?.` at the call site
- Prefer overloads over a single function with nullable/default parameters when the two variants have meaningfully different behaviour — Kotlin overloads are idiomatic and cheap

## KMP / commonMain

- No imports from `android.*`, `java.*`, `javax.*`, `dalvik.*` in `commonMain`
- Only Kotlin stdlib and KMP-compatible libraries in `commonMain`
- `expect/actual` only for platform-specific implementation details — business logic belongs in `commonMain`
- Prefer `kotlinx.*` equivalents over JVM-only alternatives (e.g., `kotlinx.datetime` over `java.time`, `kotlinx.serialization` over Gson/Moshi)

## Architecture (Clean Architecture + MVI)

- UseCases are single-responsibility: one public `operator fun invoke()` (or project's chosen convention)
- Repository **interfaces** live in the domain layer; **implementations** live in the data layer
- Domain models / entities have **no framework dependencies** (exception: `kotlinx.coroutines`, `kotlinx.datetime`, `kotlinx.serialization` annotations)
- Mappers are explicit functions or classes — never put mapping logic inside data classes
- Never expose data-layer types (DTOs, Entities) through repository interfaces — always map to domain models at the layer boundary
- `viewModelScope` / `lifecycleScope` belong in the Android presentation layer only — not in UseCases or Repositories


