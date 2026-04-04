# Migration Plan: UserRepository.kt — RxJava → Kotlin Coroutines

_Phase 1: Discover output. Awaiting user strategy selection before proceeding to Phase 2._

---

## Discovery Summary

### Target

| Property | Value |
|---|---|
| File | `UserRepository.kt` |
| Module | `:core` |
| FROM | RxJava (Singles, Observables, Completables, or Maybes — exact types inferred from usage patterns described) |
| TO | Kotlin Coroutines (`suspend fun` + `Flow`) |
| Category | `logic` + `api` (public interface used across module boundaries) |

### Codebase Impact

**Callers:** 6 ViewModels across 4 feature modules (`:feature-login`, `:feature-profile`, `:feature-settings`, `:feature-feed`).

**Module boundary:** The public interface `UserRepository` is defined in `:core`. The implementation lives in `:core` as well (inferred from description — no separate `:core-impl` module mentioned). This means the interface change in `:core` immediately affects all 4 feature modules that depend on it.

**Test coverage:** None. No existing unit tests. This is the most significant risk factor for this migration — there is no behavioral safety net before we start.

**API stability:** The public interface **will change**. RxJava return types (`Single<User>`, `Observable<List<User>>`, `Completable`, etc.) must become suspend functions or `Flow<T>`. All 6 ViewModels must be updated — this is a **breaking interface change**.

**Hidden consumers to verify before Phase 2:**
- DI bindings (Hilt/Dagger module that provides `UserRepository`) — must be updated when implementation changes
- Any `build.gradle.kts` Proguard/R8 keep rules referencing RxJava classes used by `UserRepository`
- Any Gradle tasks or CI scripts that reference specific RxJava artifacts

### Dependent Library Compatibility Audit

The following RxJava-specific artifacts are commonly present in projects using `UserRepository` with RxJava. Each must be reviewed in the affected modules' `build.gradle.kts` before Phase 2:

| Artifact | Action | Replacement |
|---|---|---|
| `io.reactivex.rxjava2:rxjava` | **Remove** (after full migration) | `org.jetbrains.kotlinx:kotlinx-coroutines-core` |
| `io.reactivex.rxjava2:rxandroid` | **Remove** | `org.jetbrains.kotlinx:kotlinx-coroutines-android` |
| `com.squareup.retrofit2:adapter-rxjava2` | **Replace** | Remove adapter; Retrofit 2.6+ has built-in `suspend` support |
| `androidx.room:room-rxjava2` | **Replace** | `androidx.room:room-ktx` (adds coroutine/Flow support to Room DAOs) |
| `com.jakewharton.rxrelay2:rxrelay` | **Remove** (if used only for UserRepository patterns) | `StateFlow` / `SharedFlow` |

> **Note:** These replacements each represent a nested decision. If Room is involved, the DAO interfaces also need migration. If Retrofit is involved, the API service interfaces need updating. The user must decide whether to fold these into scope or defer them as separate PRs. **Do not absorb these decisions silently.**

---

## Strategy Options

### Option A — Parallel (Expand-Contract) with Extension Bridge ⭐ Recommended

> **Preparation:** Write characterization tests for `UserRepository` against the existing RxJava implementation (capturing actual behavior as a safety net). No module restructuring needed — `:core` is already isolated.
>
> **Migration:**
> 1. Rewrite `UserRepositoryImpl` to use `suspend fun` / `Flow` (keep the old `UserRepository` interface temporarily).
> 2. Add `UserRepositoryCompat.kt` — extension functions re-exposing the old RxJava surface over the new suspend implementation. This keeps all 6 ViewModels compiling unchanged.
> 3. Migrate ViewModels one-by-one (one per PR or one module per PR) from RxJava calls → suspend calls. Each PR is independently buildable and rollbackable.
> 4. Once all ViewModels are migrated, update the `UserRepository` interface in `:core` to the coroutines signature.
> 5. Delete `UserRepositoryCompat.kt` and remove RxJava Gradle dependencies.
>
> **PRs:**
> - PR 1 — Snapshot: characterization tests only, no production code changes. CI must be green.
> - PR 2 — Rewrite `UserRepositoryImpl` to coroutines + add `UserRepositoryCompat.kt`. All 6 ViewModels still compile unchanged.
> - PR 3 — Migrate `:feature-login` and `:feature-profile` ViewModels to suspend (2 modules, ~2–3 ViewModels).
> - PR 4 — Migrate `:feature-settings` and `:feature-feed` ViewModels to suspend (2 modules, ~3–4 ViewModels).
> - PR 5 — Update `UserRepository` interface in `:core` to suspend/Flow signatures. Delete `UserRepositoryCompat.kt`. Remove RxJava Gradle deps. Final cleanup.
>
> **Effort:** Medium
> **Risk:** Low — each PR is independently rollbackable; no ViewModel is broken mid-migration; the bridge keeps the build green throughout.
> **Why:** 6 callers across 4 modules with no tests is precisely the scenario this strategy is designed for. The bridge layer (`UserRepositoryCompat.kt`) eliminates the need to change all 6 ViewModels at once, making each PR small and reviewable.

---

### Option B — Branch by Abstraction

> **Preparation:** Same characterization test snapshot as Option A.
>
> **Migration:**
> 1. The interface `UserRepository` already exists in `:core`. Add a new implementation `UserRepositoryCoroutinesImpl` that satisfies the **new** coroutines interface alongside the old.
> 2. Problem: the existing interface is typed in RxJava (`Single<User>` etc.). You would need a **second** interface (`UserRepositoryV2`) with coroutines signatures, or you must change the existing one — at which point this collapses into Option A anyway.
>
> **Effort:** Medium-High
> **Risk:** Medium — maintaining two interfaces temporarily adds cognitive overhead and invites drift.
> **Why not recommended:** Branch by Abstraction works when callers can stay on the old interface indefinitely. Here, the goal is to migrate callers to coroutines — so the old interface is temporary scaffolding, not a stable abstraction. Option A achieves the same isolation with less structural overhead.

---

### Not Offered

**Big Bang** — 6 callers across 4 modules with zero test coverage means any regression in a single-branch full-rewrite has no safety net and is expensive to debug. The risk profile is high with no upside; incremental migration is clearly feasible here. Dismissed.

**In-place** — The interface change is breaking (RxJava return types → suspend/Flow). All 6 ViewModels must be updated simultaneously in a single step, making the PR unreviewably large and creating a period where the build is broken. Dismissed.

**Feature-flagged Parallel** — Appropriate for UI migrations where production validation before full rollout is needed. `UserRepository` is a data-layer component — behavioral correctness is captured by tests, not A/B production rollout. Dismissed.

---

## Snapshot Blocker (Critical Path)

**There are no existing tests.** Per the migration skill's hard rule: Phase 3 (migration) cannot start until the Snapshot is green. This means:

**PR 1 must create characterization tests before any production code is touched.**

If characterization tests cannot be written (e.g., the RxJava implementation has untestable infrastructure dependencies that cannot be mocked), the team must decide:
1. Invest in making the code testable first (add interfaces/fakes for dependencies), or
2. Switch to a manual behavioral checklist (accepted risk — explicitly acknowledged by the user).

> **This decision must be made before PR 2 starts. No exceptions.**

---

## Recommended Next Steps (Awaiting User Approval)

1. **Confirm strategy** — Option A is recommended. If you prefer Option B or have constraints not captured here, say so now.
2. **Dependency audit** — Share the `build.gradle.kts` files for `:core`, `:feature-login`, `:feature-profile`, `:feature-settings`, and `:feature-feed` so the dependency compatibility matrix can be finalized. In particular: confirm whether Room DAOs and/or Retrofit service interfaces are involved.
3. **Snapshot decision** — Confirm that characterization tests can be written against the existing RxJava implementation, or state the constraint that prevents it.
4. **After approval** — Generate `migration-checklist.md` (scope involves >5 files and 4 modules) and produce `behavior-spec.md` for `UserRepository` before touching any code.

---

## Migration Checklist Preview (generated after user approves strategy)

This will be expanded after strategy confirmation into a full per-unit tracking table:

| Unit | Module | Category | Strategy | Snapshot method | Depends on |
|---|---|---|---|---|---|
| `UserRepository` (interface) | `:core` | `api` | Parallel — update last | API compilation check | All ViewModel migrations |
| `UserRepositoryImpl` | `:core` | `logic` | Parallel — rewrite first + Compat bridge | Characterization tests | — |
| `UserRepositoryCompat.kt` | `:core` | `logic` | Temporary bridge — delete in PR 5 | n/a (scaffolding) | `UserRepositoryImpl` |
| Login ViewModels (~1–2) | `:feature-login` | `logic` | In-place (per VM) | Characterization tests | `UserRepositoryImpl` (coroutines) |
| Profile ViewModels (~1–2) | `:feature-profile` | `logic` | In-place (per VM) | Characterization tests | `UserRepositoryImpl` (coroutines) |
| Settings ViewModels (~1) | `:feature-settings` | `logic` | In-place (per VM) | Characterization tests | `UserRepositoryImpl` (coroutines) |
| Feed ViewModels (~2) | `:feature-feed` | `logic` | In-place (per VM) | Characterization tests | `UserRepositoryImpl` (coroutines) |
| DI module (Hilt/Dagger) | `:core` or app | `logic` | In-place | Build compilation | `UserRepositoryImpl` (coroutines) |
| RxJava Gradle deps | all affected modules | `api` | Remove in cleanup PR | Final build green | All migrations complete |
