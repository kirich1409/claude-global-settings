# Dependencies

Never add a new dependency without explicit user approval. Prefer what's already in the project. If a new dependency is the only reasonable option, propose it and wait for go-ahead.

**Gradle / JVM:** avoid touching `.gradle` files/directories directly. Use `ksrc` to inspect dep source code (`ksrc --help`).

## Adding or upgrading a dependency — mandatory plan-stage gate

Adding a **new** dependency / plugin or **bumping** an existing one is a **plan-stage decision**, not an implementation detail. The plan cannot be finalized — and implementation cannot start — until the library is **studied** and the version is **verified**. A plan that proposes a library without these outputs is incomplete and must be revised before approval.

This rule covers Gradle / Maven plugins on equal footing with library deps — plugin id, version, and source repository all go through the same gate.

### Plan-stage outputs (must appear in the plan before approval)

For every new dependency / plugin / bumped version, the plan contains four items in this order:

1. **Identity.** Exact `groupId:artifactId` (or plugin id, or `name@registry` for non-Maven ecosystems) + the role it plays (one line: what it does, why it's needed, why existing project deps don't cover this).
2. **Freshness.** Latest stable version resolved via `maven-mcp:latest-version` (or `maven-mcp:check-deps` for the whole project; ecosystem-equivalent scanner for non-Maven — `npm view <pkg> version`, `pip index versions`, `cargo search`, etc.). Format: "latest stable: X.Y.Z". If the latest is a pre-release / RC and stable is older — pick stable and note the gap explicitly. Never pin to a version "because it was in the snippet / blog post / training data".
3. **Vulnerabilities.** `maven-mcp:check-deps-vulnerabilities` against the chosen coordinate (non-Maven → `npm audit`, `pip-audit`, `cargo audit`, etc.). Any CVE / GHSA hit → stop the plan, report severity + advisory ID + fixed-in version, propose a safe alternative or wait for user call. "No advisories" is also a valid output — state it.
4. **API surface study.** Read the actual library — for JVM/Kotlin use `ksrc` on the resolved version; for Android also use `android docs`; for other ecosystems use Context7 / DeepWiki / official docs (see the API-truth priority chain). The plan must demonstrate that the proposed integration uses the library's **current** API, not a memorized signature. For a bump that crosses a major version or a known evolving library (Ktor, Room, Compose, AGP, Hilt, kotlinx.*, etc.) — also run `maven-mcp:dependency-changes <old> <new>` and surface breaking changes / migration notes in the plan.

The plan therefore contains a block like:

```
Dependency: io.example:foo-bar  — role: <one line>
- latest stable: 1.4.2 (no advisories)
- API: studied via ksrc, entry points: FooBar.create(...), uses kotlinx.coroutines Flow
- Bump diff (1.2.0 → 1.4.2): no breaking changes in public API
```

No such block → the plan is not ready. Implementation must not begin.

### Implementation-stage check

By the time `libs.versions.toml` / `build.gradle*` / `pom.xml` / `package.json` / `Cargo.toml` / `module.yaml` is edited, the version is already approved in the plan. The implementing agent's only job at this point is: confirm the resolved version still matches the plan (no day-of bump needed) and write the edit. Do **not** silently swap versions; if the freshness check needs re-running, report it back to the main session.

### Kotlin Toolchain projects (`module.yaml`)

Для проектов на Kotlin Toolchain (присутствует `module.yaml`) применяется тот же четырёхпунктовый Plan-stage gate. Уточнения:

- **Identity / Freshness / Vulnerabilities:** зависимости в `module.yaml` — Maven coordinates, поэтому `maven-mcp` family остаётся primary (`latest-version`, `check-deps`, `check-deps-vulnerabilities`, `dependency-changes`). Не пытаться искать «Toolchain-specific scanner».
- **API surface study:** `ksrc` primary (как и для Gradle Kotlin). `kotlin-toolchain.org` НЕ источник API truth для библиотеки — он только для синтаксиса объявления зависимости в `module.yaml` и build-config обвязки.
- **Plan-stage block:** дополнительно к четырём стандартным пунктам — отметить целевой раздел `module.yaml`, куда добавляется coordinate (например, `dependencies` / `test-dependencies` / `compose-dependencies` если такой существует на текущей версии Toolchain).

### Ecosystem fallback (no maven-mcp)

If the dependency is not on Maven Central — name the ecosystem scanner explicitly in the plan output and use it. Do not silently skip checks because `maven-mcp` is the wrong tool. The four plan outputs are mandatory regardless of stack.
