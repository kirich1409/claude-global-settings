# Phase 1: Discover — RxJava → Coroutines Migration Strategy

## What I found

**FROM:** RxJava (observable streams — likely `Single<T>`, `Observable<T>`, or `Maybe<T>` return types on the `UserRepository` interface)
**TO:** Kotlin coroutines (`suspend fun` and/or `Flow<T>`)

**Target classification:**
- `logic` — repository is pure data/business logic, no UI
- `api` — the interface `UserRepository` is a public contract defined in `:core` and used across 4 modules

**Codebase impact analysis:**

| Factor | Finding |
|--------|---------|
| Callers | 6 ViewModels across `:feature-login`, `:feature-profile`, `:feature-settings`, `:feature-feed` |
| Interface location | `:core` module — a shared module boundary |
| Implementation location | `UserRepository.kt` (single file, assumed to be in `:core` or a data module) |
| Test coverage | None — no existing unit tests |
| API stability | The interface **will change** — RxJava return types become `suspend fun` / `Flow` |
| Hidden consumers to check | DI bindings (Hilt/Dagger modules providing `UserRepository`), any Proguard/R8 keep rules referencing RxJava types, any other non-ViewModel consumers not mentioned |

**Key risk:** The interface change in `:core` is a **breaking change that ripples to all 6 callers simultaneously**. There is no test safety net. This combination — breaking API surface + zero tests + 6 callers in 4 modules — rules out simple in-place replacement as a safe first move.

---

## Strategy options

> **Option A — Parallel (Expand-Contract) with behavior spec as snapshot** ← Recommended
>
> Preparation: Write a `behavior-spec.md` capturing every method's contract (inputs, outputs, error paths, edge cases) from reading the existing RxJava implementation. This serves as the snapshot since there are no tests to run. Then write characterization tests against the *current* RxJava implementation to lock in behavior before touching anything.
>
> Migration: Keep the existing RxJava `UserRepository` interface and implementation untouched. Introduce a new `UserRepositoryCoroutines` interface (same contract, coroutines-based signatures) and a new `UserRepositoryImpl` (coroutines) alongside the old one. Migrate callers one ViewModel at a time — each swap is independently buildable and rollbackable. When all 6 ViewModels are switched, rename and delete the old interface and implementation.
>
> Effort: medium
>
> Risk: low
>
> Why: With 6 callers across 4 modules and zero tests, migrating in one shot creates a large blast radius with no safety net. Parallel lets each ViewModel be switched and verified independently. The behavior spec + characterization tests fill the test gap before any code changes.

---

> **Option B — Branch by Abstraction**
>
> Preparation: Write the behavior spec (same as Option A). The existing `UserRepository` interface already acts as the abstraction layer — no new interface extraction needed. Write characterization tests against the current implementation.
>
> Migration: Add a coroutines-based implementation class behind the existing interface by wrapping: coroutine internals exposed as RxJava at the interface boundary temporarily (e.g., using `rxSingle { ... }` adapters), then migrate the interface signatures once all callers are ready to switch in one coordinated step.
>
> Effort: medium-high
>
> Risk: medium
>
> Why: Keeps callers unchanged longest, but the coordinated interface flip still touches all 6 ViewModels at once. The RxJava-to-coroutines adapter layer adds temporary complexity that must be cleaned up. Only preferable if keeping the public API stable for an extended period is a hard requirement.

---

> **Option C — Big Bang**
>
> Preparation: Write the behavior spec. Migrate everything on a feature branch: interface, implementation, and all 6 ViewModels in one pass.
>
> Migration: Full rewrite on a branch; merge when all compiles and manual testing passes.
>
> Rollback plan (required before starting): revert the branch; old RxJava code on `main` remains the fallback. Rollback trigger: if the branch is not mergeable within an agreed deadline, or if post-merge issues appear in any of the 4 modules.
>
> Effort: low (fastest calendar time if nothing goes wrong)
>
> Risk: high
>
> Why: Zero tests means no automated regression detection. A mistake in any of the 6 ViewModels or the shared interface is only caught by manual testing or CI compilation. With 4 feature modules affected, debugging a broken main branch is expensive. Only viable if the team has strong manual test coverage and a fast revert path.

---

## Before you choose

Two things I'd want to verify before committing to any option (simulated — I would search the codebase for these):

1. **DI bindings:** Is `UserRepository` bound in a Hilt/Dagger module in `:core` or elsewhere? The binding must be updated when the implementation changes. If it's in a shared `AppModule`, it touches more than just `:core`.
2. **RxJava scheduler injection:** Does the implementation accept `Scheduler` parameters or hardcode them? This affects whether the coroutines version needs a `CoroutineDispatcher` injected — and whether the characterization tests need to control threading.

These don't block the choice, but they affect the preparation step for whichever option you pick.

---

**My recommendation is Option A.** The parallel strategy is the only one that gives you independent, rollbackable steps when you have no tests and 6 callers spread across 4 modules. The behavior spec fills the snapshot gap before a single line of production code changes.

Which option do you want to proceed with?
