# Plan-stage gate for adding or updating a dependency

Never add a new dependency without the user's explicit approval. Use what the project already
has. If a new dependency is genuinely the only sensible option, propose it and wait for
agreement.

Adding a **new** dependency or plugin, or **updating** an existing one, is a **plan-stage
decision**, not an implementation detail. A plan cannot be finalised, and implementation
cannot start, until the library has been **studied** and the version **verified**. A plan that
proposes a library without this data is incomplete.

This applies to Gradle/Maven plugins as much as to library dependencies — plugin id, version,
and source repository go through the same gate.

## Required plan output

For each new dependency, plugin, or updated version, the plan carries four items in this
order:

1. **Identification.** Exact `groupId:artifactId` (or plugin id, or `name@registry` for
   non-Maven ecosystems) plus its role in one line: what it does, why it is needed, why the
   existing dependencies do not cover the job.
2. **Freshness.** Latest stable version via `maven-mcp:latest-version` (or
   `maven-mcp:check-deps` for the whole project; for non-Maven, the equivalent scanner: `npm
   view <pkg> version`, `pip index versions`, `cargo search`). Format: "latest stable: X.Y.Z".
   If the newest release is a pre-release/RC and the stable one is older, choose stable and
   note the discrepancy explicitly. Never pin a version because it appeared in a snippet, a
   blog post, or training data.
3. **Vulnerabilities.** `maven-mcp:check-deps-vulnerabilities` for the chosen coordinate (for
   non-Maven → `npm audit`, `pip-audit`, `cargo audit`). Any CVE/GHSA hit stops the plan:
   report severity, advisory ID, and the fixed version, then propose a safe alternative or
   wait for the user's decision. "No advisories" is also a valid result — state it explicitly.
4. **API study.** Read the actual library — for JVM/Kotlin use `ksrc` at the resolved version;
   for Android also `android docs`; for other ecosystems Context7 or official docs. The plan
   must demonstrate that the proposed integration uses the library's **current** API, not a
   remembered signature. For a major-version update, or a known evolving library (Ktor, Room,
   Compose, AGP, Hilt, kotlinx.*), also run `maven-mcp:dependency-changes <old> <new>` and
   include breaking changes and migration notes.

The resulting plan contains a block like:

```
Dependency: io.example:foo-bar  — role: <one line>
- latest stable: 1.4.2 (no advisories)
- API: studied via ksrc, entry points: FooBar.create(...), uses kotlinx.coroutines Flow
- Bump diff (1.2.0 → 1.4.2): no breaking changes in public API
```

No such block → the plan is not ready, and implementation does not start.

## At implementation time

By the time `libs.versions.toml` / `build.gradle*` / `pom.xml` / `package.json` /
`Cargo.toml` is edited, the version is already approved in the plan. The implementing agent's
only job here is to confirm the resolved version matches the plan and make the edit. Versions
are never changed silently; if the freshness check needs re-running, say so.

## Ecosystem fallback (no maven-mcp)

If the dependency is not on Maven Central, state explicitly in the plan output which ecosystem
scanner was used. Checks are never skipped silently just because `maven-mcp` does not apply.
All four plan outputs are required regardless of stack.

## Reading dependency sources

For Gradle/JVM, read a dependency's sources with `ksrc` (`ksrc --help`) rather than hunting
through `.gradle/` by hand. That is about *inspecting* dependencies; editing build scripts is
governed by `gradle-style`.
