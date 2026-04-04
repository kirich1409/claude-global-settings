# Phase 1: Discovery & Analysis — Retrofit+OkHttp → Ktor Migration

## FROM / TO

- **FROM:** Retrofit + OkHttp (setup via `RetrofitClient.kt`, five service interfaces)
- **TO:** Ktor Client (with its Kotlin-native coroutine-first API)

---

## What Was Found

### Target files (6 total)

| File | Category | Notes |
|---|---|---|
| `RetrofitClient.kt` | `api`, `logic` | Central setup: OkHttp client, interceptors, base URL, serialization. High blast radius — all services depend on it. |
| `UserService.kt` | `api`, `logic` | Retrofit interface; callers likely spread across ViewModels in `:app`. |
| `OrderService.kt` | `api`, `logic` | Same pattern as UserService. |
| `ProductService.kt` | `api`, `logic` | Same pattern. |
| `PaymentService.kt` | `api`, `logic` | Payment flows tend to carry extra sensitivity — more likely to have tight callers or error-handling quirks. |
| `AuthService.kt` | `api`, `logic` | Token/auth management — typically called early in the app lifecycle and referenced from interceptors too. |

All 6 files are classified `api` (public interfaces exposed to callers) and `logic` (no UI). None are `ui`.

---

### Codebase Impact Analysis

**Callers**
All five service files are likely injected or referenced directly from ViewModels and possibly from Fragments in `:app`. Because everything lives in `:app`, the blast radius of any change spans the entire module — a compile error in one service file can break the whole app build.

**Module boundary — key finding**
The networking layer is NOT isolated. It is mixed into `:app` alongside UI Fragments and ViewModels. This has two consequences:

1. Every migration step touches the same Gradle module as the UI, so a broken service file breaks Fragment compilation too.
2. `./gradlew :app:compileDebugKotlin` is a full-app compile — slow feedback loop during migration.
3. There is no clean seam to test the network layer independently.

Module isolation as a preparation step is worth serious consideration here (see Options below).

**Hidden consumer — ProGuard (critical)**
ProGuard/R8 keep rules reference some of these classes by name. This is a silent failure vector: the migration can appear to succeed in debug builds, then crash in release builds because ProGuard strips or renames Ktor classes that aren't covered by the new keep rules.

Specific risks:
- Old `-keep class ...RetrofitClient`, `-keep interface ...UserService` etc. rules become dead after migration but are harmless.
- New Ktor internals (serialization, engine, coroutine continuation classes) require their own keep rules and are not covered by the old ones.
- If Ktor serialization uses `kotlinx.serialization`, its keep rules differ from Retrofit's Gson/Moshi rules.

**Action required before migration is considered complete:** audit `proguard-rules.pro` (and any `consumer-rules.pro`) to map which rules apply to which files, and prepare replacement rules for Ktor. This must be verified with a release build, not just debug.

**Test coverage**
Assumed low (no mention of existing tests). Retrofit service interfaces often have no unit tests — they're integration-tested manually or not at all. This increases migration risk and makes the Snapshot phase harder.

**API stability**
Retrofit service interfaces are `interface` types with annotation-driven contracts. Ktor replaces this with explicit `HttpClient` call-site code. The **public interface changes** — callers that call `userService.getUser(id)` will need to be updated to call a new repository or client function. This is not an internals-only change.

**Build speed**
Unknown, but with `:app` containing UI + network + everything, build times are likely non-trivial. Module isolation would give a faster inner loop.

---

## Strategy Options

> **Option A — Branch by Abstraction with Module Isolation as Preparation (Recommended)**
>
> Preparation: Extract the 6 networking files into a new `:network` Gradle module. Introduce a repository interface layer (e.g., `UserRepository`, `OrderRepository`) that the existing ViewModels call — so callers depend on an interface, not on Retrofit directly. Run `./gradlew :network:assemble` green before touching any implementation.
>
> Migration: Implement Ktor-backed classes behind the same repository interfaces. Swap the DI binding (or manual wiring) from Retrofit implementation to Ktor implementation. ViewModels never change.
>
> Effort: high (isolation + interface layer + migration)
>
> Risk: low (callers insulated from the swap; each step independently verifiable; release build validated separately)
>
> Why: The public API changes (Retrofit interface → Ktor), but introducing a repository interface absorbs that change and keeps `:app` callers stable. Module isolation gives fast per-module build feedback and limits the blast radius. ProGuard can be updated and verified in isolation on the `:network` module's release build before merging.

---

> **Option B — Parallel (Expand-Contract) with Module Isolation as Preparation**
>
> Preparation: Extract to `:network` module (same as Option A). No repository interface needed.
>
> Migration: Add Ktor implementations alongside Retrofit ones (e.g., `UserServiceKtor.kt`). Migrate callers in `:app` one ViewModel at a time — each swap keeps the build green. Delete old Retrofit implementations once all callers are switched.
>
> Effort: high (isolation + parallel implementations + caller-by-caller swaps)
>
> Risk: medium (both implementations live simultaneously; risk of divergence if they differ subtly; each caller swap must be tested)
>
> Why: Suitable if you want to avoid introducing a new interface layer (Option A overhead). Each step is independently rollbackable. The downside vs Option A is that callers in `:app` do change — every ViewModel that calls a Retrofit service must be touched.

---

> **Option C — In-place Migration (no module isolation)**
>
> Preparation: None. Work directly in `:app`.
>
> Migration: Replace `RetrofitClient.kt` and each service file one at a time with Ktor equivalents. Update callers as you go.
>
> Effort: medium (no prep overhead)
>
> Risk: high
>
> Why to avoid: No module boundary means every compile error breaks the full app. Low test coverage means regressions are hard to catch. ProGuard changes can only be validated in a full release build, not in isolation. With 6 files and many ViewModel callers in the same module, in-place is the fastest path to a broken build that's hard to untangle. Only viable if build times are fast, test coverage is solid, and the team is comfortable with a big-bang feel spread across multiple PRs.

---

## ProGuard Note (applies to all options)

Before starting Phase 2 (Snapshot), the ProGuard rules file(s) must be audited:

1. Identify every `-keep` rule referencing Retrofit, OkHttp, or the service/client class names.
2. Record which rules cover the 6 migration targets.
3. Prepare the equivalent Ktor keep rules (Ktor engine, `kotlinx.serialization`, coroutine classes).
4. Phase 4 (Verify) must include a release build — debug is not sufficient to confirm ProGuard safety.

---

## Next Step

Which option would you like to proceed with — A, B, or C?

If you choose A or B, the next step is generating a `migration-checklist.md` covering all 6 files plus the ProGuard audit, followed by Phase 2 (Snapshot).
