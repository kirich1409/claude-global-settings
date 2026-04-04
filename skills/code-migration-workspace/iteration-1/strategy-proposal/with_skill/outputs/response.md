# Phase 1: Discover — UserRepository RxJava → Coroutines

## What I Read

(Simulated — codebase does not exist. Analysis is based on the information provided in the task.)

**Target:** `UserRepository.kt` — implementation class in `:core` module
**Interface:** `UserRepository` — public interface defined in `:core` module
**FROM:** RxJava (inferred from task statement)
**TO:** Kotlin coroutines (stated by user)

---

## Categorization

| File / Surface | Category |
|---|---|
| `UserRepository.kt` (impl class) | `logic` + `api` |
| `UserRepository` (interface in `:core`) | `api` |
| 6 ViewModel callers across 4 feature modules | `logic` (callers — indirect scope) |

The interface is the critical surface. It is public and shared across module boundaries, so its return types will change (e.g., `Observable<T>` → `Flow<T>` or `suspend fun`). This is a **breaking API change**.

---

## Codebase Impact Analysis

**Callers:** 6 ViewModels across 4 modules (`:feature-login`, `:feature-profile`, `:feature-settings`, `:feature-feed`).

**Hidden consumer check (simulated):**
- DI bindings in each feature module will reference either the interface or the impl — these must be updated when the interface changes.
- Any `CompositeDisposable` / `Disposable` management in ViewModels will need to be replaced with `viewModelScope` / `CoroutineScope`.
- If any ViewModel exposes RxJava streams directly to the UI layer (e.g., `LiveData` via `toLiveData()` from `rxjava2-extensions`), those pipelines change too.
- Proguard/R8 keep rules referencing RxJava types should be reviewed post-migration for dead rules.

**Module boundary:** Interface lives in `:core`. Impl lives in `:core`. Already isolated in its own Gradle module — no extraction needed.

**Test coverage:** None. This is the most significant risk factor. There is no behavioral safety net.

**API stability:** The public interface **will change** — RxJava return types (`Single<T>`, `Observable<T>`, `Completable`, `Maybe<T>`) become either `suspend fun` returning `T` directly, or `fun returning Flow<T>`. All 6 ViewModels and 4 modules must be updated after the interface changes.

**Build speed:** Unknown. With 4 feature modules depending on `:core`, a change to `:core`'s public interface triggers recompilation of all 4 — but this is unavoidable regardless of strategy.

---

## Confirmed FROM / TO

- **FROM:** RxJava (RxJava 2 or 3 — exact version not confirmed; would verify via `:core/build.gradle`)
- **TO:** Kotlin coroutines — `suspend fun` for single-value operations, `Flow<T>` for streams

> **Note:** Before proceeding I would normally confirm the exact RxJava version (2 vs 3) and whether the interface uses `Single`, `Observable`, `Completable`, `Maybe`, or a mix. The coroutines equivalents differ slightly per type. I am proceeding with the proposal under the assumption of a typical mixed-type interface — the strategy options below hold regardless of version.

---

## Strategy Options

**Option A — Parallel (Expand-Contract)** *(recommended)*

> Preparation: Write characterization tests against the current RxJava implementation before touching any code. This is the snapshot. No module restructuring needed — `:core` is already isolated.
> Migration: Create `UserRepositoryImpl` (coroutines) alongside the existing impl. Update the `UserRepository` interface to use `suspend`/`Flow` return types. Migrate ViewModels one-by-one — each ViewModel is independently compilable and rollbackable. Delete old RxJava impl and remove RxJava dependency from `:core` when all callers are switched.
> Effort: medium
> Risk: medium
> Why: 6 callers across 4 modules with no tests is a meaningful blast radius. Parallel gives you a working old impl while you migrate callers one-by-one, so a bad ViewModel migration never breaks the others. The interface change is unavoidable but the Parallel approach makes each ViewModel swap independently rollbackable.

---

**Option B — Branch by Abstraction**

> Preparation: Introduce a *second* interface (e.g., `UserRepositoryV2`) that uses coroutines return types. Implement it alongside `UserRepository`. Re-bind DI in each feature module to `UserRepositoryV2` one module at a time.
> Migration: Each feature module switches its ViewModel(s) to `UserRepositoryV2`. When all 4 modules are switched, rename `UserRepositoryV2` → `UserRepository` and delete the old interface.
> Effort: medium-high
> Risk: low-medium
> Why: Avoids changing the existing interface until all callers are ready, so no module is ever broken mid-migration. The cost is maintaining two parallel interfaces temporarily. Best fit if the team needs zero disruption to in-flight feature work in any of the 4 modules during the migration.

---

**Option C — In-place**

> Preparation: None beyond writing snapshot tests.
> Migration: Change the `UserRepository` interface return types directly. Fix all 6 ViewModels in one pass. Build must stay green after each ViewModel.
> Effort: low
> Risk: high
> Why: With no existing tests, no behavioral safety net, and 6 callers across 4 modules, a single mistake propagates across all modules simultaneously. There is no rollback granularity — if ViewModel 5 of 6 has a subtle behavioral regression, you have already changed everything else. Only suitable if the team has high confidence in the interface contract and can verify behavior manually for all 6 ViewModels. I am including this option for completeness but do not recommend it given the absence of tests.

---

## Waiting for Your Choice

Please choose an option (A, B, or C).

If you choose A or B, the next step before any code changes is:

1. Writing characterization tests (the snapshot) — covering all current behaviors of `UserRepository`, including edge cases, error paths, and any RxJava scheduling behavior.
2. Confirming the full `behavior-spec.md` with you before Phase 2 starts.

Since this involves >5 files (the interface + impl + 6 ViewModels = 8+ units) and a module-boundary API change, after you choose I will also generate a `migration-checklist.md` and present the full plan for your approval before touching any code.

**One question:** Do you have a preference for `suspend fun` (single-shot operations return `T` directly) vs `Flow<T>` (all operations return streams), or a mixed approach where single-value calls use `suspend fun` and list/stream calls use `Flow<T>`? This decision shapes the interface rewrite and I want to confirm it before writing the behavior spec.
