# Retrofit+OkHttp → Ktor Migration Analysis

**FROM:** Retrofit 2.x + OkHttp 4.x
**TO:** Ktor Client (JVM/Android engine)
**Scope:** Networking layer currently in `:app` module

---

## Phase 1: Discover

### What Exists

**Files in scope (6 files, all in `:app`):**

| File | Category | Description |
|------|----------|-------------|
| `RetrofitClient.kt` | `logic`, `api` | OkHttp client construction, interceptors, Retrofit instance creation, base URL config |
| `UserService.kt` | `logic`, `api` | Retrofit `@GET`/`@POST`/etc. interface for user endpoints |
| `OrderService.kt` | `logic`, `api` | Retrofit interface for order endpoints |
| `ProductService.kt` | `logic`, `api` | Retrofit interface for product endpoints |
| `PaymentService.kt` | `logic`, `api` | Retrofit interface for payment endpoints |
| `AuthService.kt` | `logic`, `api` | Retrofit interface for auth endpoints (likely token refresh, login) |

**Inferred callers (in `:app`):**

Because the networking layer lives in the same `:app` module as UI fragments and ViewModels, callers are likely:
- Multiple `*ViewModel.kt` files that directly inject or instantiate service interfaces via `RetrofitClient`
- Potentially `Fragment` or `Activity` classes that reference services directly
- Any `Repository` classes if the project uses that pattern (though their presence is unconfirmed)

The fact that everything is mixed in `:app` means there is no module boundary — callers and implementation are co-located. This is the defining constraint that shapes the strategy.

**Hidden consumers identified:**

- **ProGuard/R8 rules** — the user confirmed ProGuard rules reference some of the service classes. These keep rules preserve class names, method signatures, and sometimes `@SerializedName` annotations that Retrofit's Gson/Moshi converters rely on. After migration to Ktor, all Retrofit-specific keep rules become dead but potentially mask regressions if left in place.
- **Retrofit converter library** — the project almost certainly uses a JSON converter (`converter-gson` or `converter-moshi`). These are Retrofit-only artifacts; Ktor uses `ktor-client-content-negotiation` + `ktor-serialization-kotlinx-json` (or `ktor-serialization-gson`).
- **OkHttp `logging-interceptor`** — if used for HTTP logging, this is OkHttp-specific. Ktor has its own `ktor-client-logging` plugin.
- **Any `MockWebServer` usages in tests** — `com.squareup.okhttp3:mockwebserver` is OkHttp-tied. Ktor provides `ktor-client-mock` as a replacement.
- **CI scripts** — unlikely to reference Retrofit directly, but any script that runs specific test tasks for the networking layer could be affected by module restructuring.

---

### Dependency Compatibility Matrix

Based on the described stack (Retrofit + OkHttp in an Android project):

| Current Dependency | Action | Replacement / Notes |
|---|---|---|
| `com.squareup.retrofit2:retrofit` | **remove** | Replaced by `io.ktor:ktor-client-core` |
| `com.squareup.retrofit2:converter-gson` or `converter-moshi` | **replace** | `io.ktor:ktor-client-content-negotiation` + `io.ktor:ktor-serialization-kotlinx-json` (preferred) or `ktor-serialization-gson` if staying on Gson |
| `com.squareup.retrofit2:adapter-rxjava2` (if present) | **remove** | Ktor natively uses coroutines/suspend; no adapter needed |
| `com.squareup.okhttp3:okhttp` | **remove** (or retain as Ktor engine) | Ktor's `ktor-client-okhttp` engine wraps OkHttp internally; if using `ktor-client-android` instead, OkHttp becomes transitive-only and the explicit dep can be removed |
| `com.squareup.okhttp3:logging-interceptor` | **replace** | `io.ktor:ktor-client-logging` (uses SLF4J/Logback under the hood) |
| `com.squareup.okhttp3:mockwebserver` (test) | **replace** | `io.ktor:ktor-client-mock` — provides `MockEngine` for request/response stubbing without a real server |
| `org.jetbrains.kotlinx:kotlinx-serialization-json` | **add** (new dep) | Required if switching to kotlinx serialization; needs `kotlin("plugin.serialization")` in Gradle |

**Key nested decision for user:** The serialization library choice determines how much churn the migration causes:
- **Option A — Kotlinx Serialization:** Requires adding `@Serializable` to all data/response classes and the Kotlin serialization Gradle plugin. More churn in data classes, but aligns with Kotlin-first direction and removes Gson/Moshi entirely.
- **Option B — Retain Gson via `ktor-serialization-gson`:** Less data-class churn; drop-in for existing `@SerializedName` annotations. More conservative but keeps Gson as a runtime dependency.

This decision affects scope and must be made before Phase 2.

**Ktor version note:** Current stable release is **3.1.x** (as of early 2026). Key artifacts at `3.1.x`:
- `io.ktor:ktor-client-core:3.1.x`
- `io.ktor:ktor-client-okhttp:3.1.x` (recommended Android engine — backed by OkHttp 4.x)
- `io.ktor:ktor-client-content-negotiation:3.1.x`
- `io.ktor:ktor-serialization-kotlinx-json:3.1.x`
- `io.ktor:ktor-client-logging:3.1.x`
- `io.ktor:ktor-client-auth:3.1.x` (for token refresh / bearer auth)
- `io.ktor:ktor-client-mock:3.1.x` (test)

---

### Codebase Impact Summary

| Factor | Finding | Implication |
|---|---|---|
| **Module boundary** | Target is mixed into `:app` with UI code | No clean seam; must isolate before migrating OR accept blast radius of full `:app` |
| **Callers** | ViewModels and Fragments in same module; count unknown but likely 5–15+ call sites across services | Breaking API change affects many files simultaneously; parallel strategy required |
| **Test coverage** | Not confirmed; typical for legacy networking layers to have minimal unit tests | Snapshot phase cannot be skipped; characterization tests must be written before migration |
| **API stability** | Retrofit interfaces use annotations (`@GET`, `@POST`, `@Body`, `@Query`) that disappear entirely in Ktor; callers that inject service interfaces will need updating | Interface shape changes — this is not an internals-only change |
| **ProGuard rules** | Confirmed to reference service classes | Rules must be audited and updated; stale keeps hide regressions silently |
| **Hidden consumers** | Converter library, OkHttp logging interceptor, likely MockWebServer in tests | Each is a nested migration decision; none can be silently absorbed |
| **Build speed** | Unknown, but `:app` with UI + networking is typically large | Module isolation pays off more here |

---

## Strategy Options

### Option A — Parallel (Expand-Contract) with Module Isolation Preparation ⭐ Recommended

**Preparation:** Extract the 6 networking files into a new `:core:network` Gradle module. Run `./gradlew :core:network:assemble` green. Update ProGuard rules to reflect new class paths. This step alone has no behavior change and is independently reviewable.

**Migration:** Inside `:core:network`, introduce a `KtorNetworkClient.kt` alongside `RetrofitClient.kt`. Implement each service one by one as a Ktor-backed class (e.g., `UserServiceImpl` backed by `HttpClient` instead of a Retrofit interface). Mark the Retrofit service interfaces `@Deprecated` to turn the IDE into a migration guide. Swap callers (ViewModels/Repositories) one service at a time.

**PRs:**
- **PR 1 — Module isolation:** Extract 6 files to `:core:network`. No behavior change. ProGuard rules updated.
- **PR 2 — Snapshot:** Characterization tests for all 5 service contracts + `RetrofitClient` setup. No production code changes. All tests green.
- **PR 3 — Ktor implementation:** Add Ktor deps, implement `HttpClient` factory + one service per commit. Both old and new compile together.
- **PR 4 — Caller migration (data layer first):** Swap Repository/ViewModel callers service by service. Each commit stays green.
- **PR 5 — Bridge cleanup:** Remove `RetrofitClient.kt`, Retrofit service interfaces, Retrofit/OkHttp Gradle deps. Update ProGuard rules. Final build green.

**Effort:** Medium
**Risk:** Low-Medium

**Why:** The `:app` module mixing UI with networking is the primary risk amplifier — any compilation break during migration affects the full app build. Isolation first limits blast radius to `:core:network` and gives fast targeted builds. The parallel approach (old + new coexist) means each caller swap is independently rollbackable and reviewable, which is essential given the unknown caller count and absent test coverage. This codebase has all three indicators for module isolation: mixed module, API shape change (Retrofit annotations → Ktor DSL), and multiple unknown callers.

---

### Option B — Branch by Abstraction (no module isolation)

**Preparation:** Introduce a `NetworkService` interface hierarchy (e.g., `UserNetworkService`, `OrderNetworkService`) that the existing Retrofit implementations satisfy. Callers are updated once to depend on interfaces instead of Retrofit types — this is the only caller change.

**Migration:** Write Ktor-backed implementations behind the same interfaces. Swap the DI binding (Hilt/Koin module or manual factory) from Retrofit impl to Ktor impl. Delete Retrofit implementations.

**PRs:** PR 1: interfaces + Retrofit impls implement them + callers updated to interfaces. PR 2: Ktor implementations. PR 3: DI swap + cleanup.

**Effort:** Medium
**Risk:** Medium

**Why it's offered but not recommended:** Branch by Abstraction works when the public surface is stable and callers must not change. Here the bigger problem is the mixed module and absent tests — introducing interfaces doesn't help with test coverage, and the full `:app` blast radius remains. Option A's module isolation addresses the root structural problem; B does not. Use B only if the team decides module extraction is out of scope for this cycle.

---

**Not offered: Big Bang** — 6 service files with unknown caller count, absent characterization tests, and ProGuard coupling across all files. A Big Bang branch rewrite has no safety net; when the regression surfaces, there is no rollback path shorter than reverting the entire branch. The cost of finding a behavioral regression post-merge is disproportionate given the missing test coverage.

**Not offered: In-place** — The Retrofit annotation interface pattern (`@GET`, `@Body`, etc.) has no in-place equivalent in Ktor. Every service file requires a full structural rewrite, not an incremental edit. In-place requires each file to stay green during editing; a full structural rewrite of a Retrofit interface cannot be done in incremental green steps within the same file.

---

## ProGuard Audit (Required Before Any Migration)

The confirmed ProGuard references to service classes require specific action:

**Before migration (PR 1):**
- Identify which rules reference `UserService`, `OrderService`, `ProductService`, `PaymentService`, `AuthService`, and `RetrofitClient` — these are typically `-keep class com.example.**.UserService { *; }` or rules preserving `@SerializedName`-annotated response models
- Document each rule and its purpose (keeps class name for Gson reflection? Keeps method signatures for Retrofit? Preserves response model fields?)

**After migration (PR 5 cleanup):**
- Remove all Retrofit-specific keep rules (class names preserved for Retrofit reflection are irrelevant to Ktor)
- If switching to kotlinx serialization: `@SerializedName`-targeting rules become dead; replace with rules appropriate for `@Serializable` classes if needed (typically `kotlinx.serialization` handles R8 automatically via its Gradle plugin)
- If retaining Gson: `@SerializedName` rules may still be needed for response model classes; audit each rule individually

**Risk:** Stale ProGuard rules left after migration cause silent bloat and can mask R8 optimization failures. They must be explicitly cleaned up in the bridge-cleanup PR, not left for later.

---

## Snapshot Strategy (Phase 2 Preview)

Because there are no confirmed existing tests, Phase 2 will require writing characterization tests from scratch before any production code moves. Recommended approach for each service:

1. **`RetrofitClient.kt`** — characterize: base URL construction, interceptor chain (auth headers, logging), timeout config, any retry logic. Use `MockWebServer` (current) to record actual request/response shapes.
2. **Each service interface** — characterize: correct URL construction from `@GET`/`@POST` annotations, query parameter mapping, request body serialization, response deserialization, error response handling (4xx/5xx → exception type), and any auth header injection.
3. **`AuthService.kt`** specifically — token refresh logic is high-risk; characterize the full happy path, refresh-on-401, and concurrent refresh behavior if present.

All characterization tests must be green before PR 3 begins. If MockWebServer tests cannot compile or pass, stop and discuss with the user before proceeding.

---

## Next Step

Before Phase 2 begins, two decisions are needed from the user:

1. **Serialization library choice:** Switch to kotlinx serialization (more churn in data classes, Kotlin-first) or retain Gson via `ktor-serialization-gson` (less churn, conservative)?
2. **Module isolation confirmation:** Proceed with Option A (extract `:core:network` in PR 1), or use Option B (branch by abstraction, stay in `:app`)?

Once confirmed, a `migration-checklist.md` will be generated covering all 6 files with their category, strategy, snapshot method, and dependencies.
