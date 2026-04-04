# Phase 1: Discover — Retrofit+OkHttp → Ktor Migration

## FROM / TO

- **FROM:** Retrofit 2.9.0 + OkHttp 4.12.0 + RxJava2 adapters, Gson converter
- **TO:** Ktor Client 3.x with kotlinx.serialization, coroutines

---

## Target Inventory

| File | Category | Notes |
|------|----------|-------|
| `RetrofitClient.kt` | `api`, `logic` | DI setup — creates `Retrofit` instance, configures `OkHttpClient`, logging interceptor, Gson converter, RxJava2 adapter |
| `UserService.kt` | `api`, `logic` | Retrofit interface; callers are likely ViewModels or repositories |
| `OrderService.kt` | `api`, `logic` | Same pattern |
| `ProductService.kt` | `api`, `logic` | Same pattern |
| `PaymentService.kt` | `api`, `logic` | Same pattern — payment paths warrant extra care |
| `AuthService.kt` | `api`, `logic` | Same pattern; authentication flows affect all other services |
| ProGuard rules | `api` | Explicit `-keep` rules for one or more of these classes — silent break risk if class names or packages change |

All 6 production files are **mixed into `:app`** alongside UI fragments and ViewModels. This is the dominant risk factor driving strategy selection.

---

## Codebase Impact Analysis

### Callers
- **Unknown exact count** (no live codebase to search), but the description confirms the services are called directly from UI fragments and/or ViewModels — meaning callers are interspersed throughout `:app`, not isolated.
- Typical pattern for 5 Retrofit services in a single module: 10–30 call sites across ViewModel and Fragment classes.

### Hidden consumers
- **ProGuard rules:** Explicitly called out. Any class rename or package move requires ProGuard rule updates. These break silently at runtime (R8 strips the class), not at compile time — high-priority item.
- **RxJava2 adapter:** `adapter-rxjava2:2.9.0` is in the dependency list. If any ViewModel subscribes to `Single<T>`, `Observable<T>`, or `Completable` returned by Retrofit, those call sites must switch to coroutines/`Flow` when Ktor is adopted. This is an **API shape change**, not just an implementation swap.
- **Gson converter:** `converter-gson:2.9.0`. Ktor uses `kotlinx.serialization` or Gson via `ktor-serialization-gson`. Switching to `kotlinx.serialization` (recommended with Ktor) requires adding `@Serializable` annotations to every data class used in request/response bodies — this is additional scope beyond the 6 service files.

### Module boundary
- **Not isolated.** All networking code lives in `:app` alongside UI. This means:
  - Compile scope is the entire app module — slow feedback loop during migration.
  - Any compile error in networking code breaks all `:app` compilation including UI.
  - Blast radius of a mistake is the full app, not a bounded module.

### Test coverage
- **Unknown** (simulated scenario). Retrofit interfaces that return RxJava types are testable with MockWebServer, but this setup is frequently absent in apps at this stage of architecture. Assumed: low to no existing characterization tests for these services.

### API stability
- The public surface (Retrofit interface method signatures) **will change** — Ktor uses `suspend fun` returning direct types instead of `Observable<T>` / `Single<T>` or `Call<T>`. Every caller must be updated.
- This is a breaking interface change across all 5 services.

### Build speed
- Single large `:app` module: incremental builds will be slow. Module isolation would give targeted `./gradlew :network:assemble` feedback.

---

## Dependency Compatibility Matrix

The migration is Android-only (not KMP) based on the description, so KMP compatibility is not a hard gate. However, the current dependencies and their Ktor replacements are audited below.

| Current Dependency | Version in Use | Latest Stable | Status | Action |
|---|---|---|---|---|
| `com.squareup.retrofit2:retrofit` | 2.9.0 | 3.0.0 | **Replaced** | Remove entirely; replaced by Ktor |
| `com.squareup.retrofit2:converter-gson` | 2.9.0 | 3.0.0 | **Replaced** | Remove; use `ktor-serialization-kotlinx-json` or `ktor-serialization-gson` |
| `com.squareup.okhttp3:okhttp` | 4.12.0 | 5.3.2 | **Optional retain** | Ktor can use OkHttp as its engine (`ktor-client-okhttp`); or switch to `ktor-client-android` (CIO) |
| `com.squareup.okhttp3:logging-interceptor` | 4.12.0 | 5.3.2 | **Replaced** | Remove; use `ktor-client-logging` |
| `com.squareup.retrofit2:adapter-rxjava2` | 2.9.0 | 3.0.0 | **Replaced** | Remove; Ktor is coroutines-native; callers must switch from RxJava2 to `suspend`/`Flow` |

**Ktor replacement dependencies (latest stable: 3.4.1):**

| New Dependency | Purpose |
|---|---|
| `io.ktor:ktor-client-core:3.4.1` | Core client |
| `io.ktor:ktor-client-okhttp:3.4.1` | OkHttp engine (keeps existing OkHttp on the transport layer) |
| `io.ktor:ktor-client-content-negotiation:3.4.1` | Request/response serialization plugin |
| `io.ktor:ktor-serialization-kotlinx-json:3.4.1` | JSON via kotlinx.serialization |
| `io.ktor:ktor-client-logging:3.4.1` | Request/response logging |

**Key scope implication:** Switching to `kotlinx.serialization` requires adding `@Serializable` to all data classes used in API responses. If the codebase has many data classes (common with 5 services), this is hidden scope. Alternatively, `ktor-serialization-gson` keeps Gson (lower risk, but doesn't eliminate Gson dependency).

---

## Strategy Proposals

**Option A — Module Isolation + Branch by Abstraction** (recommended)

> Preparation: Extract networking code from `:app` into a new `:network` Gradle module. Define a technology-neutral repository interface (e.g., `UserRepository`, `OrderRepository`) in a `:domain` module or in `:network` itself. Update ProGuard rules to reflect new package paths. Add characterization tests for each repository interface before touching any implementation.
>
> Migration: Implement Ktor-backed versions of each repository behind the existing interface (`KtorUserRepository`, etc.). Swap DI binding from Retrofit implementation to Ktor implementation one service at a time. Callers (ViewModels/Fragments) never change their call sites — they depend on the interface.
>
> PRs:
> - PR 1: Extract `:network` module — move the 6 files, update ProGuard, wire DI, green build. No behavior change.
> - PR 2: Add repository interfaces + characterization tests (MockWebServer or similar). Snapshot green.
> - PR 3: Add Ktor dependencies + `KtorClient.kt` setup. Both `RetrofitClient` and `KtorClient` coexist.
> - PR 4: Implement `KtorUserRepository` + `KtorAuthService` (auth first — all other services depend on token management). Swap DI binding. Tests green.
> - PR 5: Implement remaining Ktor repositories (`Order`, `Product`, `Payment`). Swap bindings one-by-one. Tests green after each.
> - PR 6: Cleanup — remove Retrofit/OkHttp deps, delete `RetrofitClient.kt`, old Retrofit interfaces, ProGuard cleanup.
>
> Effort: medium-high
> Risk: low
> Why: The services are mixed into `:app` with no isolation, and the interface changes from RxJava2 to coroutines. Branch by Abstraction limits blast radius — ViewModels never touch Ktor directly, so ViewModel churn is zero. Module extraction gives fast compile feedback per PR. ProGuard breaks silently at runtime; isolating the module first makes the package rename a contained, reviewable change.

---

**Option B — Parallel (Expand-Contract) in-place, no module extraction**

> Preparation: Add characterization tests for each Retrofit service using MockWebServer. ProGuard rules audited and documented.
>
> Migration: Add Ktor dependencies alongside Retrofit. Implement Ktor equivalents of each service (e.g., `KtorUserService.kt`) in the same `:app` module. Migrate callers service-by-service: UserService → OrderService → ProductService → PaymentService → AuthService (or AuthService first if token refresh is centralized). Each caller migrated from RxJava2 Retrofit call to `suspend`/coroutine Ktor call. Build green after each service migration.
>
> PRs:
> - PR 1: Characterization tests + ProGuard audit. No production code change.
> - PR 2: Ktor setup (`KtorClient.kt`) + add deps. Old and new coexist.
> - PR 3: Migrate `AuthService` callers to Ktor (auth affects all other services; safest to do first).
> - PR 4: Migrate `UserService` + `ProductService` callers.
> - PR 5: Migrate `OrderService` + `PaymentService` callers.
> - PR 6: Cleanup — remove Retrofit/OkHttp, delete old service interfaces, ProGuard cleanup.
>
> Effort: medium
> Risk: medium
> Why: Faster to start (no module restructuring PR), but the blast radius stays wide — any mistake in a Ktor implementation breaks `:app` entirely. The RxJava2→coroutines shape change means every ViewModel call site must be updated, which increases reviewer burden per PR. ProGuard stays harder to audit without package isolation. Viable if module extraction is explicitly out of scope.

---

**Not offered: Big Bang**

> All 6 files with an interface shape change (RxJava2 → coroutines) and no test coverage means a Big Bang rewrite on a branch has no safety net. A regression in payment or auth flows would only surface at merge or in QA, at which point root-causing it across a full-app rewrite is expensive. Explicitly dismissed.

**Not offered: In-place**

> In-place (replace Retrofit with Ktor directly inside each existing service file) is ruled out because the public interface changes — `Single<T>` → `suspend fun T`. Every caller must be updated simultaneously with the implementation change. With 5 services and unknown caller count across ViewModels and Fragments in `:app`, "simultaneously" means a PR that touches dozens of files at once. That's not safely reviewable and is not independently rollbackable per service.

---

## ProGuard Note (applies to all options)

ProGuard rules referencing Retrofit service interfaces by class name (e.g., `-keep interface com.example.app.network.UserService`) will break silently if the classes are moved to a new package (`:network` module) without updating the rules. This must be treated as a first-class deliverable in whichever option is chosen — not an afterthought. In Option A, PR 1 contains the ProGuard update and is verified before any migration starts. In Option B, PR 1 documents and audits the rules; updates ship with each service migration PR.

---

## Awaiting User Decision

Please choose an option (A or B) before Phase 2 begins. If Option A is chosen, a `migration-checklist.md` covering all 7 units (6 files + ProGuard) will be generated for your approval before any code is written.

Also confirm one open question:

**Should the JSON serialization library switch from Gson to kotlinx.serialization, or stay on Gson (using `ktor-serialization-gson`)?**

- kotlinx.serialization is the idiomatic Ktor choice and removes the Gson dependency entirely, but requires adding `@Serializable` to every API data class — additional scope.
- Keeping Gson via `ktor-serialization-gson` is lower risk and less scope, at the cost of keeping a Gson dependency.
