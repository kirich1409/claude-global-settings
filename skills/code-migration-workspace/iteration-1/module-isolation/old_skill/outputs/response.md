# Phase 1: Discovery — Retrofit+OkHttp → Ktor Migration

## What Was Found

**FROM:** Retrofit 2 + OkHttp (interface-based HTTP client with annotations)
**TO:** Ktor Client (coroutine-native HTTP client)

### Files in scope

| File | Category | Notes |
|------|----------|-------|
| `RetrofitClient.kt` | `api` | OkHttp client builder, Retrofit instance, interceptors (auth, logging), base URL config |
| `AuthService.kt` | `api` + `logic` | Login, token refresh, logout endpoints |
| `UserService.kt` | `api` + `logic` | User profile CRUD endpoints |
| `OrderService.kt` | `api` + `logic` | Order listing, creation, status endpoints |
| `ProductService.kt` | `api` + `logic` | Product catalog, search, detail endpoints |
| `PaymentService.kt` | `api` + `logic` | Payment initiation, status, history endpoints |

**Total: 6 files.** All are `api` category (they define the public network interface consumed by the rest of `:app`). Several also carry `logic` if they contain suspend functions, response mapping, or error handling inline.

### Callers analysis

- **Mixed into `:app`** — the services are consumed directly by ViewModels and possibly Fragments inside the same module.
- **Estimated caller surface:** with 5 service interfaces and a shared client setup, expect 10–20+ ViewModel/Repository callers across the `:app` module.
- **Interface shape:** Retrofit services are interfaces with annotation-driven methods. Callers depend on return types — typically `Response<T>`, `Call<T>`, or suspend functions returning `T`. Ktor uses a very different call style; the public interface **will change** at the call site unless an abstraction layer is introduced.

### Hidden consumers — risk flags

- **ProGuard/R8 keep rules** reference these classes by name. If files are renamed or deleted without updating ProGuard rules, the release build will silently strip them, causing runtime crashes in production. These rules must be updated as part of cleanup.
- **OkHttp interceptors** (auth token injection, certificate pinning, logging) are likely wired in `RetrofitClient.kt`. Ktor handles these via plugins (`Auth`, `Logging`, `HttpTimeout`) — the behavior must be explicitly re-mapped, not assumed to carry over.
- **Error handling conventions:** Retrofit raises `HttpException` or returns `Response<T>` with an error body. Ktor throws `ResponseException` or requires explicit `response.status` checks. If callers catch `HttpException`, they will break silently unless error handling is migrated alongside the service layer.

### Module boundary

The networking layer is **mixed into `:app`** alongside UI fragments and ViewModels. This means:
- No Gradle boundary protects the network layer from UI code
- A build error in the network layer blocks the entire app from compiling
- `./gradlew :app:assemble` rebuilds everything on each change — slow feedback loop
- Blast radius of a bad change is the entire `:app` module

### Test coverage

Not read directly (simulated discovery), but a mixed `:app` module with Retrofit services embedded alongside UI code is typically **low on unit test coverage** for the network layer. Assume no characterization tests exist for the service interfaces until proven otherwise.

### API stability

The public interface **will change.** Retrofit's annotation-based interface (`@GET`, `@POST`, `suspend fun foo(): Response<T>`) does not map 1:1 to Ktor's call style (`client.get<T> { url(...) }`). Unless a repository/abstraction layer already wraps the service interfaces, callers will need to be updated.

---

## Recommended Approach: 3 Options

---

> **Option A — Branch by Abstraction + Module Isolation (recommended)**
> Preparation: Extract the 6 network files into a new `:network` Gradle module. Introduce a technology-neutral interface for each service (e.g., `UserRepository`, `OrderRepository`) that callers depend on instead of the Retrofit interface directly.
> Migration: Implement Ktor versions behind the new interfaces. Swap the DI binding from Retrofit impl → Ktor impl. Callers never change their import — they already use the repository interface.
> Effort: high
> Risk: low
> Why: The networking layer is mixed into a large module with many callers, and the public interface will change. Isolating first limits blast radius to the `:network` module boundary and lets `./gradlew :network:assemble` give fast feedback. Abstracting behind interfaces means ViewModel/Fragment callers are untouched during the actual Retrofit→Ktor swap, eliminating the largest source of migration risk. ProGuard rules for the new module are scoped separately, making the cleanup step safe and auditable.

---

> **Option B — Parallel (Expand-Contract) in `:app`, no module extraction**
> Preparation: None — migrate inside `:app` as-is.
> Migration: Add Ktor dependencies alongside Retrofit. Implement `KtorUserService`, `KtorOrderService`, etc. as parallel classes. Update ViewModels/Repositories one-by-one to use Ktor variants. Delete Retrofit classes when all callers are switched.
> Effort: medium
> Risk: medium
> Why: Faster to start than Option A — no module extraction overhead. However, the blast radius remains the full `:app` module. Each Ktor implementation competes for build time with the full UI layer, and a mistake in the network layer blocks the whole app from compiling. ProGuard keep rules must be found and updated by hand without a module boundary to guide the audit.

---

> **Option C — In-place migration, service by service**
> Preparation: None.
> Migration: Replace each service file in-place: remove Retrofit annotations, rewrite method bodies using Ktor `HttpClient`. Repeat for all 5 services and `RetrofitClient.kt`.
> Effort: low
> Risk: high
> Why: Only viable if callers already go through a repository/abstraction layer that hides the Retrofit types. If ViewModels import Retrofit interfaces directly, each file change will cascade into compile errors across `:app`. The ProGuard rules will also break on the first file rename. Given the described codebase structure (services mixed in with UI), in-place is likely to produce a broken intermediate state that is hard to roll back.

---

**Waiting for your choice (A, B, or C) before proceeding to Phase 2.**

Once you choose, if the chosen option involves >5 files or module restructuring (Option A does), I will generate a `migration-checklist.md` with one row per unit and present it for your approval before any code changes begin.
