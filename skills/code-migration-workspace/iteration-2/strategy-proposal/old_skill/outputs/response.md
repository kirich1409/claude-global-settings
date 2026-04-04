# Migration Planning: UserRepository.kt — RxJava → Kotlin Coroutines

## Phase 1: Discover

### Target

**File:** `UserRepository.kt` (implementation class)
**Interface:** `UserRepository` (defined in `:core` module)
**FROM:** RxJava (inferred — standard Android reactive layer; Singles/Observables/Completables typical for repository pattern)
**TO:** Kotlin Coroutines (`suspend fun` / `Flow`)

---

### Categorization

| Unit | Categories | Rationale |
|---|---|---|
| `UserRepository` interface (`:core`) | `logic`, `api` | Public contract; shared module boundary; defines the surface all 6 ViewModels depend on |
| `UserRepositoryImpl` (implementation) | `logic` | Pure data/business logic; no UI; wraps a data source |
| 6 ViewModels across 4 modules | `logic`, `ui` | Consume repository; typically bind results to LiveData/StateFlow for UI layer |

---

### Codebase Impact Analysis

#### Callers

- **6 ViewModels** in 4 modules: `:feature-login`, `:feature-profile`, `:feature-settings`, `:feature-feed`
- Each ViewModel depends on the `UserRepository` interface, not the implementation — DI injects the concrete class

#### Interface location

The public interface lives in `:core`. Any change to method signatures in `UserRepository` is an **API-breaking change** across all 4 feature modules simultaneously. Even changing return types from `Single<T>` to `suspend fun ... : T` or `Flow<T>` is a breaking change at the call sites.

#### Hidden consumers (flagged for verification before Phase 2)

These are commonly missed and should be verified in the real codebase:
- **DI binding** (Hilt/Koin/Dagger module): binds `UserRepositoryImpl` to `UserRepository`; must be updated when implementation changes
- **Proguard/R8 keep rules**: if `UserRepository` or `UserRepositoryImpl` are kept by name, the rules may reference the old class shape
- **Any RxJava schedulers** set up in Application or DI graph (e.g., `RxAndroidSchedulers.mainThread()`) — these disappear entirely when RxJava is removed
- **Any error handling middleware** that handles `RxJava2Exception` or wraps `onErrorReturn` — these are silent behavioral changes if dropped

#### Module boundary

The interface is already in a dedicated `:core` module — this is favorable. The implementation likely lives in `:core` or in a `:data` module. Module isolation is **not needed as a preparation step** — the boundary already exists.

#### Test coverage

**None.** No existing unit tests. This is the highest-risk factor in the entire scope:
- There is no safety net to catch behavioral regressions
- The migration cannot rely on "tests green before = behavior preserved"
- Snapshot (Phase 2) must write characterization tests from scratch before any code moves

#### API stability

The public interface **will change**. RxJava return types (`Single<T>`, `Observable<T>`, `Completable`, `Maybe<T>`) cannot be the same as coroutine return types (`suspend fun`, `Flow<T>`). Every method signature in `UserRepository` will change. This is a **breaking API change** — all 6 ViewModels must be updated.

#### Build speed

Unknown without access to the real project. If the project build is slow, the existing module boundary (`:core` is already isolated) already provides `./gradlew :core:assemble` as a fast feedback loop.

#### KMP compatibility

Not applicable — this is an RxJava → Coroutines migration within Android, not a KMP migration.

---

### Strategy Options

> **Option A — Parallel (Expand-Contract) with Extension Function Bridge** — RECOMMENDED
>
> **Preparation:** Write characterization tests for `UserRepository` (all methods, all paths, edge cases) before touching any code. No module restructuring needed — the interface is already in `:core`.
>
> **Migration:**
> 1. Rewrite `UserRepositoryImpl` to use `suspend fun` / `Flow` (new technology, implementation-first)
> 2. Add `UserRepositoryCompat.kt` — a temporary bridge file that re-exposes the old RxJava surface using `rxSingle { }`, `rxObservable { }`, etc., wrapping the new suspend functions
> 3. The interface in `:core` **stays RxJava** at this step — all 6 ViewModels compile unchanged
> 4. Migrate ViewModels one module at a time: `:feature-login` → `:feature-profile` → `:feature-settings` → `:feature-feed`. For each module: update the ViewModel to call suspend functions directly, update the interface in `:core` incrementally (or introduce the coroutine surface on the interface as the last caller per method switches)
> 5. Once all 6 ViewModels are switched: update the `UserRepository` interface to the final `suspend fun` / `Flow` signatures, delete `UserRepositoryCompat.kt`, remove RxJava dependencies
>
> **PRs:**
> - PR 1 (Snapshot): Characterization tests only — no production code changes. Must be green before PR 2 merges.
> - PR 2 (Implementation): Rewrite `UserRepositoryImpl` to coroutines + add `UserRepositoryCompat.kt` bridge. All ViewModels still compile unchanged. Snapshot tests green.
> - PR 3 (Caller migration — batch 1): Migrate `:feature-login` and `:feature-profile` ViewModels to suspend/Flow. Snapshot tests green.
> - PR 4 (Caller migration — batch 2): Migrate `:feature-settings` and `:feature-feed` ViewModels. Snapshot tests green.
> - PR 5 (Cleanup): Update `UserRepository` interface to final coroutine signatures. Delete `UserRepositoryCompat.kt`. Remove RxJava Gradle deps. Final build green.
>
> **Effort:** Medium
> **Risk:** Low–Medium
>
> **Why:** 6 callers across 4 modules with no tests means any simultaneous change is expensive to debug. The bridge keeps all callers compiling while the implementation migrates, making each PR independently rollbackable. Writing characterization tests first (PR 1) gives a safety net before any code moves — without it, regressions are invisible.

---

> **Option B — Branch by Abstraction (introduce new coroutine interface alongside old)**
>
> **Preparation:** Same — write characterization tests first.
>
> **Migration:**
> 1. Introduce `UserRepositoryCoroutines` interface in `:core` alongside the existing `UserRepository` interface
> 2. Implement it in a new `UserRepositoryCoroutinesImpl`
> 3. Migrate ViewModels one-by-one to depend on `UserRepositoryCoroutines` instead of `UserRepository`
> 4. Once all 6 ViewModels switch: rename `UserRepositoryCoroutines` → `UserRepository`, delete old interface and impl
>
> **PRs:** Same 5-PR structure as Option A but with two parallel interfaces instead of a compat bridge file.
>
> **Effort:** Medium–High
> **Risk:** Low
>
> **Why:** Keeps both interfaces alive simultaneously — zero risk of breaking a caller during migration. Costs more: two interface definitions to maintain in sync during the transition, more DI bindings to manage. Worth choosing over Option A only if the team cannot tolerate any compile-time breakage at the interface level during migration.

---

**Not offered:**

> **Big Bang** — No tests + 6 callers across 4 modules makes a single-branch rewrite dangerous. A regression has no safety net and is expensive to locate after a full rewrite. Rollback means reverting the entire branch. Not viable here.

> **In-place (direct replacement without bridge)** — The interface signature change means all 6 ViewModels and the `:core` interface must change simultaneously. That is too broad a blast radius for a single step with no tests. If done incorrectly, the entire project stops compiling with no incremental rollback path.

---

### Pre-Phase 2 Questions (require user decision before starting)

Before writing any characterization tests, confirm the following:

1. **RxJava types in use:** Which RxJava return types does `UserRepository` currently expose? (`Single`, `Observable`, `Completable`, `Maybe`, combinations?) This determines which coroutine equivalents to use (`suspend fun`, `Flow`, `suspend fun` returning `Unit`) and how the compat bridge is written.

2. **ViewModels' consumption pattern:** Do the ViewModels subscribe on specific schedulers (e.g., `observeOn(AndroidSchedulers.mainThread())`) or does a base class handle threading? This affects where Dispatcher decisions land after migration.

3. **Error handling:** Are RxJava `onErrorReturn`, `onErrorResumeNext`, or `doOnError` used in the repository or at ViewModel call sites? These map to `runCatching`, `catch { }` on Flow, or `CoroutineExceptionHandler` — they must be preserved exactly.

4. **Interface change scope:** Is the goal to have the final `UserRepository` interface expose `suspend fun` / `Flow`, or only to change the implementation while keeping the interface RxJava-based (for other consumers not listed)? The strategy differs significantly.

5. **DI framework:** Hilt, Koin, or manual DI? Affects how the binding swap in PR 5 is done.

---

**Waiting for user to choose a strategy option (A or B) before proceeding to Phase 2.**
