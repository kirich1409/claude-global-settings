---
name: insnc-di-seam
description: Insync 3.0 Android hybrid DI architecture — Hilt app graph + per-feature isolated Koin, and the exact Hilt↔Koin bridge seam through protocol/dependency
type: project
---

Insync 3.0 (insnc-android) hybrid DI — verified 2026-06-10 on worktree-kmp-di-research (branch off development, NO Metro present: 0 Metro/kotlin-inject files; the `tech/metro-di-migration` branch from auto-memory is NOT in this repo).

**Scale (195 gradle modules):** feature=62, protocol=28, feature_modules=26, utility_modules=23, new-core=23, mobile-services=21, transfer=8.

**DI footprint:**
- Hilt: ~1005 files, 191 `@InstallIn` modules, 199 `@HiltViewModel`. Concentrated in `:app` (535 files), `feature_modules` (195), `utility_modules` (98), `core` (35). All `@HiltViewModel` live in app/core/feature_modules — ZERO in new `feature/`.
- Koin: ~589 files. 514 in new `feature/`. 282 `viewModel{}`/`viewModelOf` DSL resolutions in `feature/`. Koin annotations (KSP) barely used: 33 files.
- Two DI worlds split by module era: legacy (feature_modules/core/app) = Hilt; new `feature/` = isolated Koin.

**The Hilt↔Koin bridge (the critical seam):** lives in `protocol/presentation/dependency`:
- `interface Dependencies` (empty marker) — each feature declares `XxxDependencies : Dependencies` in its `api/` with the externally-required deps as `val`s.
- `HasDependencies { val dependenciesMap: DependenciesMap }` where `DependenciesMap = Map<Class<out Dependencies>, Dependencies>`.
- `IsolatedKoinContext` / `IsolatedKoinComponent` / `KoinContextProvider` interfaces.
- Flow: a **host Activity in `:app`** (`@AndroidEntryPoint`, implements `HasDependencies`) gets the feature's `Dependencies` impl `@Inject`ed as a qualified `DependenciesMap`. A Hilt `@Module` in `:app` (`provideXxxDependencies` returning `object : XxxDependencies`) builds that impl from the app graph. The feature's internal `IsolatedKoinContext` (`koinApplication { }`) then seeds its isolated Koin graph from those deps.
- Seam count: ~91 `DependenciesMap` provider sites in `:app`, ~61 `object : XxxDependencies` impls in `:app`, ~49 `XxxDependencies` interfaces across feature dirs. ~63 host Activities in `:app` implement `HasDependencies`.

**Each feature defines its OWN `IsolatedKoinContext` object** (not shared) — e.g. `ConverterIsolatedKoinContext`, ~15+ such objects, each a thin `koinApplication { androidContext; modules(...) }` wrapper. Not reused via the protocol interface; the protocol interface is the contract, concrete impl is per-feature.

**build-logic convention plugins (DI-relevant):** `InsyncAndroidLibraryHiltPlugin` (applies hilt+ksp, adds hilt-android impl + compiler ksp, composed via `alias(libs.plugins.insync.library.android.hilt)`), `InsyncMultiplatformLibraryPlugin` (already EXISTS — KMP target androidMain/iosArm64/iosSimulatorArm64/jvm, commonMain deps kotlinx-datetime/coroutines/serialization). No Koin convention plugin — features apply Koin deps directly.

**ViewModel factory:** `BaseViewModel<E : UiEvent>` in `protocol/presentation/viewmodel`. `IViewModelDelegate` chain (IRetryManager/IViewModelErrorManager/IViewModelDownloadManager) in `core` via `ViewModelDelegateModule`. Feature Koin ViewModels resolve via `viewModel{}` DSL; legacy via `@HiltViewModel`.

**Integration points:** 17 `:sample` submodules (isolated feature dev — each re-wires DI), 4 WorkManager/HiltWorker files, Navigation SafeArgs (XML nav graphs in :app, set via `setInSyncGraph`).
