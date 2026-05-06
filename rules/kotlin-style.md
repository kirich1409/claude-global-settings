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
