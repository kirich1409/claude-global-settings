# Migration Plan: UserRepository — RxJava → Kotlin Coroutines

## Phase 1 Findings (Discover)

### Target

| Item | Value |
|------|-------|
| File | `UserRepository.kt` (implementation) |
| Interface | `UserRepository` (defined in `:core`) |
| FROM | RxJava (`Single`, `Observable`, `Completable`, or similar) |
| TO | Kotlin coroutines (`suspend fun` / `Flow`) |

### Codebase Impact Analysis

| Factor | Finding |
|--------|---------|
| **Callers** | 6 ViewModels across 4 feature modules |
| **Modules affected** | `:core` (interface), `:feature-login`, `:feature-profile`, `:feature-settings`, `:feature-feed` |
| **Module boundary** | Interface is a cross-module public API — any change to the interface signature is a breaking change for all 6 callers simultaneously |
| **Test coverage** | None — no existing characterization tests |
| **API stability** | The public interface **will change** (RxJava return types → `suspend fun` / `Flow`) |
| **Hidden consumers** | Not confirmed — DI bindings (Dagger/Hilt/Koin), ProGuard keep rules, and any event-bus or broadcast wiring should be verified before migration starts |

### Dependent Library Compatibility

These RxJava-adjacent dependencies are commonly present and must be audited in the affected modules' `build.gradle.kts` before starting:

| Artifact | Category | Action |
|----------|----------|--------|
| `io.reactivex.rxjava2:rxjava` | Replace | Remove after migration; no longer needed |
| `io.reactivex.rxjava2:rxandroid` | Replace | Remove after migration |
| `com.squareup.retrofit2:adapter-rxjava2` | Replace | Swap to built-in `suspend` support in Retrofit 2.6+ |
| `androidx.room:room-rxjava2` | Replace | Swap to `androidx.room:room-ktx` (exposes `Flow` / `suspend`) |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | Add | Required for coroutines on Android |
| `org.jetbrains.kotlinx:kotlinx-coroutines-core` | Add | Required |
| Any custom RxJava schedulers / thread utilities | Remove | Replace with coroutine dispatchers (`Dispatchers.IO`, etc.) |

> Each "Replace" item is a nested decision. Recommendation: handle all dependency swaps in a dedicated **Preparation PR** before touching the implementation. This keeps the migration PRs focused on behavior, not build config.

---

## Strategy Options

### Option A — Parallel (Expand-Contract) with Extension Function Bridge ⭐ Recommended

**Preparation:** Audit DI bindings; add `kotlinx-coroutines-android` / `kotlinx-coroutines-core` to `:core` and feature modules; swap RxJava-adjacent library artifacts; add a `migration-checklist.md` and produce `behavior-spec.md` (manually, since there are no tests).

**Migration:**
1. Rewrite `UserRepository` implementation to use `suspend fun` / `Flow` (Direction A bridge).
2. Add `UserRepositoryCompat.kt` in `:core` that wraps the new `suspend` API back into RxJava types — keeps all 6 ViewModels compiling unchanged.
3. Mark old RxJava-style methods in the interface `@Deprecated(level = WARNING)` with `ReplaceWith` pointing to the new suspend form.
4. Migrate ViewModels one-by-one (one feature module per PR): each ViewModel is updated to call the `suspend` form directly; compile and snapshot-verify after each.
5. Once all callers are switched: delete `UserRepositoryCompat.kt`, remove RxJava dependencies, switch deprecation to `ERROR` to catch any stragglers, then remove the annotation entirely.

**PRs:**
- PR 1 — Preparation: dependency swaps, DI audit, `migration-checklist.md`, `behavior-spec.md` (no behavior change)
- PR 2 — Snapshot: characterization tests for `UserRepository` behavior (covers all method contracts — written against the still-RxJava implementation)
- PR 3 — Implementation rewrite: new `suspend`/`Flow` impl + `UserRepositoryCompat.kt` bridge; all snapshot tests must stay green
- PR 4 — Caller migration batch 1: `:feature-login` + `:feature-profile` ViewModels switched to `suspend`
- PR 5 — Caller migration batch 2: `:feature-settings` + `:feature-feed` ViewModels switched to `suspend`
- PR 6 — Bridge cleanup: delete `UserRepositoryCompat.kt`, remove RxJava deps, final build green

**Effort:** Medium
**Risk:** Low — at no point are more than one or two callers broken at a time; every PR is independently rollbackable.

**Why:** 6 callers across 4 modules with zero test coverage is the textbook case for Parallel/Expand-Contract. The bridge keeps callers compiling while the implementation migrates; callers then move at a controlled pace one module at a time. The `@Deprecated(ReplaceWith)` annotation turns the IDE into a migration guide and enables batch application of the quick-fix across all call sites.

---

### Option B — Branch by Abstraction

**Preparation:** Same as Option A.

**Migration:** Introduce a new interface `UserRepositoryV2` in `:core` with `suspend fun` / `Flow` signatures. Implement it as `UserRepositoryImplV2`. Update DI to bind `UserRepositoryV2`. Migrate each ViewModel to depend on `UserRepositoryV2` rather than `UserRepository`. Once all callers are on `V2`: rename `UserRepositoryV2` → `UserRepository`, delete old interface and implementation.

**PRs:** Similar breakdown to Option A, but callers change their injected type, not just the method calls.

**Effort:** Medium-high (rename/repackage step at the end is noisy)
**Risk:** Low-medium — introduces an extra interface that must be maintained in sync until cutover; rename at the end touches many files at once.

**Why consider it:** Valid if you want the old interface to remain completely untouched until all callers are ready — useful if there are other consumers of `UserRepository` outside the 4 feature modules that cannot be migrated in this batch.

**Recommended only if:** There are callers outside the 4 listed modules that are not in scope for this migration. If the 6 ViewModels are the only callers, Option A is cleaner.

---

### Not Offered

**Big Bang** — 6 callers across 4 modules with no tests means a regression has no safety net and could be invisible until QA. A full-codebase rewrite on a branch is expensive to review, produces a giant diff, and if it breaks, rollback means reverting all 4 feature modules at once. Dismissed.

**In-place** — The public interface signature changes (RxJava types → `suspend`/`Flow`). In-place would require updating the interface, all 6 ViewModels, and the implementation simultaneously. That is too broad for a single coherent step without tests. Dismissed.

---

## Migration Checklist (draft — to be filled out after user approves strategy)

| Unit | Category | Strategy | Snapshot Method | Dependencies |
|------|----------|----------|-----------------|--------------|
| `UserRepository` interface (`:core`) | api | Parallel + bridge | Behavior spec (manual; no tests) | None — migrated in PR 3 |
| `UserRepositoryImpl` (`:core`) | logic | Parallel (impl-first) | Characterization tests (PR 2) | Interface bridge in place |
| `UserRepositoryCompat.kt` (`:core`) | api | Bridge (temporary) | Compiles; snapshot tests green | New impl done |
| ViewModel callers in `:feature-login` (N callers) | logic | Caller migration | Tests green after swap | Bridge in place |
| ViewModel callers in `:feature-profile` (N callers) | logic | Caller migration | Tests green after swap | Bridge in place |
| ViewModel callers in `:feature-settings` (N callers) | logic | Caller migration | Tests green after swap | Bridge in place |
| ViewModel callers in `:feature-feed` (N callers) | logic | Caller migration | Tests green after swap | Bridge in place |
| `UserRepositoryCompat.kt` | — | Delete | Final build green | All callers migrated |
| RxJava Gradle deps | — | Remove | Final build green | Bridge deleted |

> N callers per module to be filled in after reading the actual ViewModels.

---

## Behavior Specification Template (to be completed in Phase 2)

```markdown
# Behavior Specification: UserRepository
FROM: RxJava → TO: Kotlin coroutines (suspend fun / Flow)

## Public Interface
| Method / Property | Inputs | Output / Side Effect | Notes |
|---|---|---|---|
| (to be filled after reading UserRepository.kt) | | | |

## Normal Behaviors
- (to be filled after reading UserRepository.kt)

## Edge Cases
- (to be filled after reading UserRepository.kt)

## Quirks (preserve exactly unless user decides otherwise)
- (to be filled after reading UserRepository.kt)

## Out of Scope
- RxJava threading (subscribeOn/observeOn) — replaced by coroutine dispatchers
```

---

## Open Questions / Decisions Needed Before Starting

1. **DI framework** — Is the project using Dagger/Hilt, Koin, or manual injection? This affects how the implementation swap is wired in PR 3.

2. **Retrofit / Room** — Does `UserRepositoryImpl` use Retrofit for network calls and/or Room for local storage? If yes, the dependency compatibility table above applies directly.

3. **Callers outside the 4 modules** — Are there any other consumers of `UserRepository` not mentioned (e.g., `:core` itself, WorkManager workers, BroadcastReceivers)? If yes, Option B (Branch by Abstraction) becomes more attractive.

4. **`Flow` vs `suspend fun`** — For methods that return lists or streams (e.g., "observe all users"), do you want `Flow<List<User>>` (continuous stream) or `suspend fun getUsers(): List<User>` (one-shot)? This should be decided before writing the behavior spec. Recommendation: use `Flow` only for data that genuinely needs live updates; use `suspend fun` for everything else.

5. **Snapshot approach** — Since there are no existing tests, characterization tests must be written against the current RxJava implementation before any code changes. This is a hard requirement per the migration workflow. If writing tests now is not feasible, the fallback is a manual behavior checklist — but this increases regression risk significantly. Confirm the approach before starting Phase 2.

---

## Next Step

Please review the options above and confirm:

1. Which strategy to use (Option A recommended)
2. Answers to the 5 open questions above

After confirmation, Phase 2 (Snapshot) begins: produce `behavior-spec.md` from reading `UserRepository.kt` and write characterization tests against the current RxJava implementation before any production code is touched.
