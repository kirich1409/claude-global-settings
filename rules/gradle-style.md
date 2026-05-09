# Gradle Build Script Rules

Applies to Gradle build scripts only: `*.gradle.kts`, `*.gradle`, `settings.gradle*`, convention plugins under `build-logic/` and `buildSrc/`.

## Dependency configuration — `implementation` by default, `api` only when types leak

For every dependency, pick the narrowest configuration that still works. Priority:

1. **`implementation`** — first choice. The dependency is used internally; its types do not appear in the module's public API. Consumers don't see it on their compile classpath, rebuilds stay isolated.
2. **`api`** — only when the dependency's types appear in this module's *public* surface and downstream modules need to reference those types directly. Concretely: types of `public`/default-visibility return values, public-API parameters, public class hierarchies, annotations on public symbols, generic type arguments on public APIs.
3. **`compileOnly`** / **`runtimeOnly`** — for Gradle plugin classpath needs, annotation processors with optional runtime, or libraries provided by the host (Android SDK, plugin runtime).

Apply the same priority to test configurations (`testImplementation` over `testApi`) and to KMP source sets (`commonMain.dependencies { implementation(...) }` first; `api(...)` only when needed by consuming source sets / modules).

### How to decide

A dependency belongs in `api` if **any** of these hold:
- A `public`/default-visibility type from the dependency appears in the signature of a `public`/default-visibility declaration of this module.
- A consumer module would otherwise have to redeclare the same dependency just to reference a type that this module already exposes.
- The dependency provides a public DSL or extension API that consumers invoke directly via this module.

Otherwise — `implementation`. Default `public` symbols in Kotlin make this easy to miss; check `kotlin-style.md`'s visibility rule first to ensure the symbol is actually meant to be public.

### Why it matters

- `implementation` keeps Gradle's classpath isolation intact — touching one module doesn't recompile downstream consumers, and ABI changes in the dep don't ripple.
- `api` is a transitive contract: every consumer of this module gets the dep on their compile classpath whether they want it or not. Misused `api` inflates the rebuild graph and creates accidental coupling.
- The cost of fixing later is asymmetric: tightening `api` → `implementation` is a breaking change for anyone who relied on the leak; widening `implementation` → `api` is trivial.

### When unsure

Pick `implementation`. Compile failure in a consumer module is a clean signal to widen; silent transitive leaks are not.

## Version catalogs and convention plugins

- New dependencies go into `gradle/libs.versions.toml` (or the project's version catalog file). Don't hardcode coordinates in module build scripts.
- Repeated build configuration belongs in convention plugins (`build-logic/`), not duplicated across module build scripts.
- For multi-module repos, before adding a new dependency to a leaf module, check whether a convention plugin or upstream module already provides it transitively.
