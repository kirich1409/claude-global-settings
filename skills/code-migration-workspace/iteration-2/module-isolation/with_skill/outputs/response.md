# Phase 1: Discover — Retrofit → Ktor Migration

FROM: Retrofit 2.9.0 + OkHttp 4.12.0 + RxJava2 adapter
TO: Ktor Client 3.4.1 + kotlinx.serialization + coroutines

---

## 1. Target Inventory

Six files identified in the networking layer, all currently in `:app`:

| File | Category | Notes |
|------|----------|-------|
| `RetrofitClient.kt` | `api`, `logic` | Central setup: OkHttp builder, logging interceptor, Gson converter, Retrofit instance. Public entry point for all services. |
| `UserService.kt` | `api`, `logic` | Retrofit interface; likely exposes RxJava `Single`/`Observable` or suspend funs. |
| `OrderService.kt` | `api`, `logic` | Same pattern as UserService. |
| `ProductService.kt` | `api`, `logic` | Same pattern. |
| `PaymentService.kt` | `api`, `logic` | Same pattern. Likely highest-risk: payment flows are sensitive and often have extra headers/auth logic. |
| `AuthService.kt` | `api`, `logic` | Same pattern. Likely touches token refresh / interceptor logic wired into `RetrofitClient`. |

All six files are in `:app`, mixed in with UI fragments and ViewModels. This is a public API within the module — ViewModels and fragments are callers.

---

## 2. Codebase Impact Analysis

### Callers
Because the files are simulated (not on disk), exact call counts are estimated from the described structure:

- **RetrofitClient.kt** — called by every service instantiation site and likely by DI setup or Application class. If there is no DI framework, this may be called in 5–10 places (one per ViewModel or fragment that needs a service). If Hilt/Dagger/Koin is present, it's probably wired in one module.
- **Service interfaces (5 files)** — each is injected into at least one ViewModel; AuthService likely injected into multiple places (login, registration, token refresh interceptor).
- **Estimated total callers:** 8–15 ViewModel/Fragment files, plus the DI wiring point, plus any unit tests that mock services.

### Hidden Consumers
- **ProGuard/R8 rules** — explicitly called out in the task description. Rules reference these classes by name. If class names change (they will when moving away from Retrofit interfaces), keep rules will produce silent dead code rather than runtime crashes. Must update during cleanup.
- **Retrofit interface annotations** — `@GET`, `@POST`, `@Body`, `@Query`, etc. are Retrofit-specific and exist in service interface files. All must be removed.
- **Gson converter** — `converter-gson` serializes/deserializes. Moving to Ktor with `kotlinx-serialization` requires annotating all model data classes with `@Serializable`. Model classes are not in scope for the service files themselves, but they are a ripple dependency — any model used in a service response type must be updated.
- **RxJava2 adapter (`adapter-rxjava2`)** — this is a significant hidden scope item; see dependency audit below.
- **OkHttp `logging-interceptor`** — Ktor has its own `ktor-client-logging` plugin; the OkHttp interceptor is replaced, not just removed.

### Module Boundary
The networking layer is NOT in its own Gradle module. It lives in `:app` alongside UI code. This is the single highest-risk structural factor: any compilation error in the migrated layer breaks the entire `:app` build, including all UI. There is no `:gradlew :networking:assemble` fast-feedback loop.

### Test Coverage
No existing tests mentioned. This is a red flag: the characterization snapshot in Phase 2 will need to be written from scratch before any migration begins.

### API Stability
The **public interface changes** — Retrofit service interfaces are Retrofit-specific constructs and cannot be kept as-is for Ktor. Callers (ViewModels) will need to be updated. If services currently return `Single<T>` (RxJava), this change is doubly breaking because both the networking library AND the reactive type change.

### Build Speed
Unknown without access to the project, but a large `:app` module with UI + networking + business logic is typically slow to compile. Module isolation would give meaningful `./gradlew :network:assemble` speedup.

---

## 3. Dependent Library Compatibility Audit

This is a Retrofit → Ktor migration, which is a foundational technology change. All Retrofit-specific adapters and converters are affected.

| Dependency (current) | Version | Latest | Category | Action Required |
|---|---|---|---|---|
| `com.squareup.retrofit2:retrofit` | 2.9.0 | 3.0.0 | **remove** | Replaced by `io.ktor:ktor-client-core:3.4.1`. Remove entirely. |
| `com.squareup.retrofit2:converter-gson` | 2.9.0 | 3.0.0 | **remove** | Gson serialization replaced by `io.ktor:ktor-client-content-negotiation:3.4.1` + `io.ktor:ktor-serialization-kotlinx-json:3.4.1`. All response model classes must gain `@Serializable`. |
| `com.squareup.retrofit2:adapter-rxjava2` | 2.9.0 | 3.0.0 | **remove** (nested decision — see below) | Ktor has no RxJava adapter. Native Ktor uses suspend functions / Flow. This dependency implies the service interfaces return `Single<T>` or `Observable<T>`, which means ViewModels consume RxJava. Removing this forces a coroutines migration of callers simultaneously, OR requires a bridge layer. **This is the highest-impact dependency change and requires an explicit user decision.** |
| `com.squareup.okhttp3:okhttp` | 4.12.0 | 5.3.2 | **compatible** (optional engine reuse) | Ktor on Android typically uses `ktor-client-okhttp` as its engine, which bundles OkHttp. The standalone `okhttp` dep can be removed once Ktor is the sole consumer. OkHttp 5.x is available but Ktor 3.4.1 engine bundles its own compatible version — do not upgrade separately. |
| `com.squareup.okhttp3:logging-interceptor` | 4.12.0 | 5.3.2 | **remove** | Replaced by `io.ktor:ktor-client-logging:3.4.1`. OkHttp interceptor-based logging does not carry over to Ktor's plugin architecture. |

### Ktor artifacts to add

| Artifact | Version | Purpose |
|---|---|---|
| `io.ktor:ktor-client-core` | 3.4.1 | Core Ktor client |
| `io.ktor:ktor-client-okhttp` | 3.4.1 | Android engine (uses OkHttp under the hood) |
| `io.ktor:ktor-client-content-negotiation` | 3.4.1 | Replaces converter-gson |
| `io.ktor:ktor-serialization-kotlinx-json` | 3.4.1 | JSON serialization (replaces Gson) |
| `io.ktor:ktor-client-logging` | 3.4.1 | Replaces OkHttp logging-interceptor |
| `io.ktor:ktor-client-auth` | 3.4.1 | Auth plugin (replaces manual auth interceptor in RetrofitClient) |
| `io.ktor:ktor-client-mock` | 3.4.1 | Test engine (needed for characterization tests) |
| `org.jetbrains.kotlinx:kotlinx-serialization-json` | 1.10.0 | Required by ktor-serialization-kotlinx-json |

Also requires: `kotlin("plugin.serialization")` in the Gradle plugin block, and `@Serializable` on all network response models.

### The RxJava2 Nested Decision — User Must Decide

`adapter-rxjava2` is present, which means the 5 service interfaces almost certainly return `Single<T>` or `Observable<T>`. Ktor's native API is suspend functions. This creates a choice that cannot be absorbed silently:

**Option RX-A — Migrate to coroutines as part of this migration (recommended)**
Convert service return types to `suspend fun` and update ViewModels to consume coroutines. This is the right long-term direction. Adds effort (ViewModel changes) but eliminates a dead-end tech stack.
Bridge artifact needed during transition: `org.jetbrains.kotlinx:kotlinx-coroutines-rx2:1.10.2` can wrap coroutines in RxJava for ViewModels not yet migrated.

**Option RX-B — Keep RxJava surface, wrap Ktor in RxJava bridge**
Ktor calls are suspended internally; bridge functions re-expose `Single<T>` to existing ViewModels. Uses `rxSingle { }` from `kotlinx-coroutines-rx2`. ViewModels don't change. Adds permanent complexity and postpones the coroutines migration.

**Option RX-C — Defer: migrate Retrofit to Ktor only where services use suspend funs today**
If some services already use `suspend fun` (Retrofit 2.6+ supports this natively), migrate those first. Leave RxJava-returning services for a separate coroutines migration PR.

This decision must be made before proceeding. It affects which PRs are in scope and how callers are split.

---

## 4. ProGuard Impact

ProGuard rules reference the current service classes by name. The specific impact:

- Retrofit service interfaces (e.g., `UserService`, `OrderService`) are kept by ProGuard because Retrofit uses reflection to generate implementations. After migration, Ktor does not use reflection on service interfaces (there are no interfaces — you write direct `HttpClient` calls). The old keep rules become dead but harmless.
- **Risk:** if the keep rules reference Retrofit internal classes (e.g., `retrofit2.**`), those rules will keep dead Retrofit code in the release build even after Retrofit is removed from Gradle — unless R8's shrinking catches it (it usually does, but it's noise). Remove the rules explicitly during cleanup.
- **Action:** during Phase 4 cleanup, audit ProGuard rules and remove all Retrofit-specific keep rules. Add rules for `kotlinx.serialization` if not already present (it requires keep rules for `@Serializable` classes to prevent R8 from stripping serializer metadata).

---

## 5. Module Boundary Assessment

The networking layer is mixed into `:app`. Module isolation is strongly recommended as a preparation step because:

1. The migration changes the public API of the networking layer (service interfaces disappear; direct `HttpClient` DSL calls replace them). Without isolation, the blast radius of a compilation error is the entire `:app` including all UI.
2. Extracting to `:network` enables `./gradlew :network:assemble` — fast feedback loop during migration.
3. It cleanly separates the ProGuard rules concern: a dedicated `:network` module can have its own consumer ProGuard rules file.
4. `:network` isolation is also a prerequisite if KMP is ever on the roadmap (Ktor is KMP-native; Retrofit is not).

Isolation sequence: extract the 6 files into `:network` module → wire DI → `./gradlew :network:assemble` green → begin migration inside `:network`.

---

## 6. Strategy Options

### Option A — Parallel (Expand-Contract) with Module Isolation Preparation ⭐ recommended

**Preparation:** Extract the 6 networking files from `:app` into a new `:network` Gradle module. Wire existing DI to consume from `:network`. Confirm `./gradlew :network:assemble` is green. Also decide the RxJava question (Option RX-A recommended) before starting migration. Write characterization tests for all 6 files using `ktor-client-mock` in a snapshot PR.

**Migration:**
1. Add Ktor dependencies to `:network`. Introduce `KtorClient.kt` alongside `RetrofitClient.kt` — both compile simultaneously.
2. For each service, write a `KtorUserService.kt` etc. implementing the same logical API (suspend funs) alongside the Retrofit interface. Mark Retrofit interface `@Deprecated(level = WARNING)`.
3. Migrate ViewModels one-by-one from Retrofit service → Ktor service; build stays green after each swap (RxJava bridge layer buffers ViewModels not yet migrated).
4. When all callers switched: remove `RetrofitClient.kt`, Retrofit service interfaces, `converter-gson`, `adapter-rxjava2`, `okhttp` (standalone), `logging-interceptor`.
5. Update ProGuard rules.

**PRs:**
- PR 1: Extract `:network` module, wire DI — no behavior change
- PR 2: Characterization tests (snapshot) for all 6 service files — no production code change
- PR 3: Add Ktor deps + `KtorClient.kt` + 5 Ktor service implementations (compile alongside Retrofit)
- PR 4: Migrate ViewModels batch 1 (non-auth, non-payment — lower risk)
- PR 5: Migrate ViewModels batch 2 (auth + payment — higher risk, separate for reviewability)
- PR 6: Remove Retrofit, OkHttp standalone, Gson converter, RxJava adapter; update ProGuard

**Effort:** high
**Risk:** low — each PR is independently rollbackable; regressions are caught per-batch
**Why:** The networking layer has no tests, is mixed into a large module, has a breaking API change (Retrofit interfaces → Ktor DSL), and carries an RxJava → coroutines sub-migration. Parallel strategy with isolation gives the smallest blast radius at each step and makes each PR reviewable in isolation. The characterization test PR (PR 2) is the safety net — it cannot be skipped.

---

### Option B — Branch by Abstraction (no module isolation)

**Preparation:** Introduce a `NetworkService` interface per domain (e.g., `UserNetworkService`, `OrderNetworkService`) that both the Retrofit and Ktor implementations satisfy. Wire DI to inject the interface. Write characterization tests against the interface.

**Migration:** Implement Ktor-backed concrete classes. Swap DI bindings one interface at a time. Delete Retrofit implementations when all bindings are swapped.

**PRs:**
- PR 1: Add interfaces + Retrofit implementations behind interfaces (DI swap only)
- PR 2: Characterization tests
- PR 3: Ktor implementations, DI swap per service
- PR 4: Remove Retrofit, cleanup

**Effort:** medium
**Risk:** medium — avoids module isolation overhead but keeps the blast radius in `:app`. Interface introduction in PR 1 is non-trivial if ViewModels currently instantiate Retrofit services directly. RxJava still must be resolved.
**Why offered:** viable if module isolation is blocked by timeline or team bandwidth. The interface layer provides rollback at the DI level without requiring a new Gradle module.

---

**Not offered: Big Bang**
Six service files with no existing tests and ViewModels mixed throughout `:app` means a regression has no safety net and would be invisible until QA or production. The RxJava sub-migration makes this even riskier — a full rewrite branch is expensive to validate and nearly impossible to roll back cleanly. Dismissed.

**Not offered: In-place**
The API surface changes (Retrofit interfaces → Ktor HttpClient calls), which forces simultaneous updates to all ViewModel callers. With no tests and callers spread across a large `:app`, there is no safe stopping point. In-place would require the entire `:app` module to be broken mid-migration. Dismissed.

---

## 7. Decisions Required Before Phase 2

The following must be resolved before any snapshot or migration work begins:

1. **RxJava strategy:** choose RX-A (migrate to coroutines), RX-B (keep RxJava surface via bridge), or RX-C (defer). This determines ViewModel scope and the PR breakdown for caller migration.

2. **Module isolation:** confirm whether `:network` extraction is in scope (strongly recommended). If timeline blocks it, Option B proceeds without it — but the risk profile changes.

3. **Gson → kotlinx.serialization:** confirm that all network response model classes can receive `@Serializable` annotation. If any model class is a third-party type or generated code, a custom serializer will be needed — this should be identified before migration starts.

4. **ProGuard audit:** provide the current ProGuard rules that reference the networking classes so they can be assessed for cleanup scope.

Once these four questions are answered, the migration checklist (`migration-checklist.md`) will be generated and Phase 2 (Snapshot) can begin.
