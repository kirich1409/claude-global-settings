# Migration Planning: UserRepository.kt — RxJava → Kotlin Coroutines

## Phase 1: Discover

---

### Step 1 — Target Read

**Target:** `UserRepository.kt` — the concrete implementation of the `UserRepository` interface.

Based on the task description, the target is simulated as follows:

```
:core module
  └── UserRepository.kt (interface definition — public API surface)

Implementation class (likely :core or :data module):
  └── UserRepositoryImpl.kt (RxJava-based implementation)

Callers:
  :feature-login     — ViewModel(s) using UserRepository
  :feature-profile   — ViewModel(s) using UserRepository
  :feature-settings  — ViewModel(s) using UserRepository
  :feature-feed      — ViewModel(s) using UserRepository
  Total: 6 ViewModels across 4 feature modules
```

---

### Step 2 — FROM Technology (inferred)

The implementation uses **RxJava 2** (io.reactivex.rxjava2). Typical surface based on the described pattern:

```kotlin
interface UserRepository {
    fun getUser(id: String): Single<User>
    fun updateUser(user: User): Completable
    fun observeUsers(): Observable<List<User>>
    fun deleteUser(id: String): Completable
}
```

The implementation (`UserRepositoryImpl`) likely uses:
- Room with `room-rxjava2` for local persistence
- Retrofit with `adapter-rxjava2` for network calls
- `rxandroid` for `AndroidSchedulers.mainThread()` scheduling

---

### Step 3 — TO Technology (from user input)

**Kotlin Coroutines + Flow** (standard modern Android replacement for RxJava):

```kotlin
interface UserRepository {
    suspend fun getUser(id: String): User
    suspend fun updateUser(user: User)
    fun observeUsers(): Flow<List<User>>
    suspend fun deleteUser(id: String)
}
```

---

### Step 4 — Categorize

| File / Unit | Categories | Notes |
|---|---|---|
| `UserRepository` (interface in `:core`) | `api`, `logic` | Public interface — **breaking change** affects all 6 callers across 4 modules |
| `UserRepositoryImpl` (implementation) | `logic` | Business logic + data access; internals change completely |
| 6 ViewModels across 4 feature modules | `logic` | Must be updated to use `suspend`/`Flow` instead of RxJava operators |
| `build.gradle.kts` files (affected modules) | `api` | Dependency additions/removals |

This is a **cross-module, breaking interface change**. The interface lives in `:core`, which all 4 feature modules depend on. Changing the interface signature forces a simultaneous update of all 6 ViewModels.

---

### Step 5 — Codebase Impact Analysis

#### Callers

| Caller Location | Count | Impact |
|---|---|---|
| `:feature-login` ViewModels | ~1–2 | Must switch from `.subscribe()` / `.observe()` to `viewModelScope.launch` / `.collect()` |
| `:feature-profile` ViewModels | ~1–2 | Same |
| `:feature-settings` ViewModels | ~1–2 | Same |
| `:feature-feed` ViewModels | ~1–2 | Same |
| **Total** | **6** | All 6 must be updated |

#### Hidden Consumers to Check

- **Proguard/R8 keep rules:** Any `-keep class io.reactivex.**` rules may become dead weight — flag for cleanup.
- **DI bindings (Hilt/Dagger/Koin):** The module that provides `UserRepository` will need to change its binding from `UserRepositoryImpl` (RxJava) to a coroutines-based implementation. If Hilt is used, `@Provides` or `@Binds` in a `@Module` file will need updating.
- **Gradle tasks:** No known tasks are likely to reference this repository directly, but Gradle module dependency declarations will change when RxJava deps are removed.
- **CI scripts:** No expected impact unless CI has explicit RxJava instrumented test shards.

#### Module Boundary

The interface is already in `:core` — a dedicated module. This is **already isolated at the module level**. No extraction needed.

#### Test Coverage

**No existing unit tests.** This is the highest-risk factor in this migration. There is no behavioral safety net. The Snapshot phase (Phase 2) must create characterization tests from scratch before any production code is touched.

#### API Stability

The public interface **will change** — `Single<User>` → `suspend fun getUser(): User`, `Observable<List<User>>` → `Flow<List<User>>`, etc. This is a **breaking change to the module's public API**. All 6 callers must be updated as part of the migration; they cannot stay on the old surface.

Because the interface changes, this cannot be treated as an internal-only migration — every caller must participate.

#### Build Speed

Not directly measured, but with 4 feature modules + 1 core module, the build is likely moderately slow. The modules are already isolated, which means `./gradlew :core:assemble` and per-feature compile tasks give fast feedback loops.

---

### Step 5b — Dependent Library Compatibility Check

The following libraries are typically used in a RxJava-based Android repository. Checked via maven-mcp for current latest versions and migration status:

| Library (current role) | Current Latest | Replacement | Action | Notes |
|---|---|---|---|---|
| `io.reactivex.rxjava2:rxjava` (2.2.21) | 2.2.21 | `org.jetbrains.kotlinx:kotlinx-coroutines-core` (1.10.2) | **Replace** | Core RxJava runtime — remove after migration |
| `io.reactivex.rxjava2:rxandroid` (2.1.1) | 2.1.1 | `org.jetbrains.kotlinx:kotlinx-coroutines-android` (1.10.2) | **Replace** | Android scheduler — remove after migration; coroutines-android provides `Dispatchers.Main` |
| `com.squareup.retrofit2:adapter-rxjava2` (3.0.0) | 3.0.0 | None needed | **Remove** | Retrofit 2.6+ has built-in `suspend fun` support; no adapter required for coroutines |
| `androidx.room:room-rxjava2` | 2.8.4 | `androidx.room:room-ktx` (2.8.4) | **Replace** | Same Room version — `room-ktx` adds `suspend` and `Flow` support; straightforward swap |
| `com.squareup.retrofit2:retrofit` | 3.0.0 | Same | **Compatible** | Retrofit itself is technology-agnostic; suspend support is built in since 2.6 |
| `org.jetbrains.kotlinx:kotlinx-coroutines-core` | 1.10.2 | — | **Add** | New dependency |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | 1.10.2 | — | **Add** | New dependency |
| `androidx.room:room-ktx` | 2.8.4 | — | **Add** | New dependency (same version family as existing Room) |

**Summary of dependency decisions required:**

1. **`room-rxjava2` → `room-ktx`**: Both are at `2.8.4` — this is a clean same-version swap. No API-level Room migration needed. This can be handled in the preparation PR.

2. **`adapter-rxjava2`**: Can be deleted outright — Retrofit's built-in suspend support is available from 2.6 onward (latest is 3.0.0). If the project is on Retrofit < 2.6, it must be upgraded first (this is a pre-step). **Assumption: project is on Retrofit 2.6+.**

3. **`rxjava` and `rxandroid`**: Deleted at the end of migration (cleanup PR), not before — the bridge layer during migration will still use RxJava temporarily.

None of these dependency changes represent a breaking API migration of their own. This is the best-case dependency scenario for a RxJava → coroutines migration.

---

### Step 6 — Strategy Options

#### Context summary driving the proposal

| Factor | Finding | Impact on strategy |
|---|---|---|
| Callers | 6 ViewModels, 4 modules | Large scope — incremental caller migration is valuable |
| Interface change | Breaking — all callers must update | Cannot do a purely internal migration |
| Test coverage | **Zero** | Characterization tests must be written before any code changes |
| Module isolation | Already isolated in `:core` | No extraction needed |
| Dependencies | Clean swap — no nested breaking migrations | Low dependency risk |
| Interface location | `:core` — all 4 feature modules depend on it | Interface change must be carefully sequenced |

---

> **Option A — Parallel (Expand-Contract) with Implementation-first Bridge** ⭐ recommended
>
> **Preparation:** Write characterization tests for `UserRepositoryImpl` (the only snapshot available given zero existing tests). Add coroutines dependencies. Swap `room-rxjava2` → `room-ktx`. Remove `adapter-rxjava2`.
>
> **Migration:**
> 1. Rewrite `UserRepositoryImpl` to use `suspend fun` and `Flow` internally.
> 2. Add `UserRepositoryCompat.kt` — a temporary bridge that re-exposes the old RxJava interface (`Single<User>`, `Completable`, `Observable<List<User>>`) by wrapping the new suspend/Flow implementation using `rxSingle { }`, `rxCompletable { }`, `rxObservable { }` (from `kotlinx-coroutines-rx2`).
> 3. All 6 ViewModels continue to compile unchanged.
> 4. Migrate ViewModels one-by-one from the old RxJava surface to the new `suspend`/`Flow` surface. Commit after each ViewModel.
> 5. Once all 6 ViewModels are migrated: update the `UserRepository` interface in `:core` to the coroutines signatures.
> 6. Delete `UserRepositoryCompat.kt`. Remove RxJava dependencies.
>
> **PRs:**
> - PR 1 (Preparation): Add characterization tests, swap `room-rxjava2` → `room-ktx`, add `kotlinx-coroutines-*`, add `kotlinx-coroutines-rx2` (bridge artifact, temporary), remove `adapter-rxjava2`. No production logic changes.
> - PR 2 (Implementation): Rewrite `UserRepositoryImpl` + add `UserRepositoryCompat.kt`. All existing tests must pass. All 6 ViewModels still compile against the RxJava compat surface.
> - PR 3 (Callers: Login + Profile): Migrate 2–3 ViewModels from RxJava → coroutines. Tests green.
> - PR 4 (Callers: Settings + Feed): Migrate remaining ViewModels. Tests green.
> - PR 5 (Cleanup): Update `UserRepository` interface in `:core` to coroutines signatures. Delete `UserRepositoryCompat.kt`. Remove `rxjava`, `rxandroid`, `kotlinx-coroutines-rx2`. Rebuild — all green.
>
> **Effort:** Medium
>
> **Risk:** Low
>
> **Why:** The bridge layer (Direction A) decouples the implementation rewrite from the caller migration — each step is independently rollbackable and CI-verifiable. With 6 callers across 4 modules and no tests, incremental steps with a green build at each stage is the safest path. The dependency swap is clean (no nested migrations), and the existing module isolation means blast radius is contained.

---

> **Option B — Branch by Abstraction (new interface + dual implementation)**
>
> **Preparation:** Same as Option A (tests, deps).
>
> **Migration:** Introduce a `UserRepositoryV2` interface with coroutines signatures. Write `UserRepositoryImplV2` (coroutines). Update DI to bind `UserRepositoryV2`. Migrate ViewModels to inject `UserRepositoryV2` one-by-one. Once all callers switched: rename `UserRepositoryV2` → `UserRepository`, delete old interface and implementation.
>
> **PRs:** Similar split — Preparation, new interface + new impl, caller batches, rename + cleanup.
>
> **Effort:** Medium-High
>
> **Risk:** Low-Medium
>
> **Why:** Viable, but adds unnecessary complexity for this case. Because the `UserRepository` interface is already well-defined and the migration is to a direct coroutines equivalent, introducing a `V2` interface creates extra cognitive overhead (two interfaces in `:core`, DI binding changes twice). Option A achieves the same incremental safety with less structural noise. Offer this if the team prefers explicit interface versioning over a compat bridge file.

---

**Not offered:**

> **Big Bang** — 6 callers across 4 modules with zero tests means a regression has no safety net and would be expensive to diagnose. A single giant PR touching the interface, all callers, and the implementation simultaneously cannot be meaningfully reviewed or rolled back. Dismissed.

> **In-place** — the interface change is breaking, which means all 6 ViewModels must be updated the moment the `:core` interface changes. This forces everything to happen simultaneously — exactly the scenario in-place is unsuitable for. Dismissed. (In-place works when the change is internal-only; this is not that case.)

> **Feature-flagged Parallel** — this is a repository layer, not a UI migration. Feature flags are appropriate for screen-by-screen UI rollouts or behavioral changes needing production validation. They add deployment complexity (flag lifecycle, server config) with no benefit for a data-layer migration. Dismissed.

---

## Waiting for User Choice

Please choose a strategy before Phase 2 begins:

1. **Option A** (recommended) — Implementation-first bridge, migrate callers incrementally, 5 PRs
2. **Option B** — Dual-interface approach (`UserRepositoryV2`), migrate callers incrementally, similar PR structure

Also confirm:

- Is the project using **Retrofit 2.6 or later**? (Determines whether `adapter-rxjava2` removal is safe immediately.)
- Are there any **Hilt / Dagger / Koin** DI modules that bind `UserRepository`? (Affects which files are in scope for each PR.)
- Any **instrumented tests** (UI or integration tests) that exercise the repository layer? (Even if unit tests are absent, these would affect the snapshot strategy.)

Phase 2 (Snapshot — writing characterization tests) will not begin until a strategy is chosen and these questions are answered.
