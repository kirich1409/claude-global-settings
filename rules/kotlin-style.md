# Kotlin Code Style Rules

Applies to `.kt` and `.kts` files only.

## Visibility — minimum by default

The visibility of every declaration must be the narrowest one that still works. Always pick from this priority:

1. **`private`** — first choice. Used inside one file or one class only.
2. **`internal`** — next choice. Used across files inside the same module.
3. **`public`** — last resort. Only for declarations that are intentionally part of the module's external API surface.

Do not leave declarations at default `public` visibility "just because it compiles". Default `public` is a deliberate API decision, not a fallback.

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
