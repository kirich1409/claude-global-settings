---
name: insnc-kmp-phase1-boundary
description: Insync 3.0 KMP Phase-1 common/android boundary in :protocol — what moved to commonMain, the ApiUrlProvider seam verdict, and the seam-scaling risk for Phase 2-3
type: project
---

KMP Phase-1 boundary of `:protocol` split (reviewed 2026-06-15 on worktree `kmp-phase1`, branch `tech/kmp-phase1-protocol`). Approach = move-not-rewrite (user invariant); arch verdict = no BLOCK, boundary drawn correctly, no cycles. Related: [[insnc-di-seam]], [[ui-logic-split-di-seam]].

**What moved to commonMain (real common, NOT pseudo-android-only):**
- `:protocol:presentation:viewmodel` — BaseViewModel/BaseMviViewModel/EmptyProtocolViewModel/ErrorStateProtocol/UiEvent/InitForm. `BaseViewModel : androidx.lifecycle.ViewModel` + `viewModelScope` in commonMain.
- `:protocol:presentation:error` — BaseErrorState (deparcelized @Parcelize→@Serializable) + ErrorResponseMapper.
- `:protocol:data:source:error` — ErrorResponse + DTO enums (DisplayType/AuthType/...) + GeneralApiException/NoLocationGrantedException. (EncryptionType/DeviceStatus/EncryptionDepth stayed in androidMain.)
- `:protocol:data:source:response` — only TokenType moved; ~55 other DTOs stayed androidMain (src/main).
- `:protocol:data:source:serialization` — only UrlDeserializer moved; amount/date serializers stayed androidMain.
- `:new-core:navigation` — NavGraphRoutes.kt (plain String consts). `:new-core:utils:platform` — StateUtils.kt (withLoading).

**Why common is real here (not the development-era pseudo-common):** `InsyncMultiplatformLibraryPlugin` declares real `iosArm64()/iosSimulatorArm64()/jvm()/android` (plugin file lines 78-80). KMP-published deps resolve in commonMain: androidx.lifecycle 2.10.0 (lifecycle-viewmodel KMP since 2.8), androidx.annotation 1.9.1, kermit 2.1.0, kotlinx-io-core 0.7.0. So VisibleForTesting (androidx.annotation) and ViewModel in commonMain genuinely compile for iosArm64. CAVEAT: nav-contract only confirms navigation:compileKotlinIosArm64 green — VM/error iosArm64 green still needs verification at acceptance.

**IMPORTANT — `src/main/` = androidMain under the KMP plugin.** Plugin maps `androidMain.kotlin.srcDir("src/main/kotlin")` (lines 60-64, "temporary compat with Android source dir"). So files left in `src/main/` are NOT dead — they are androidMain. A module having BOTH `commonMain/` and `main/` is the normal split state, not a leftover bug.

**ApiUrlProvider seam (the one non-trivial design decision):** `object ApiUrlProvider { var resolver: () -> String = { "" }; val actualUrl get() = resolver() }` in network:utils commonMain. Android's `InsncNetworkConfig.init { ApiUrlProvider.resolver = { actualUrl } }` wires it. Purpose = break common→androidMain edge: UrlDeserializer (common) needs base URL but used to reference InsncNetworkConfig (android, OkHttp/SSL). **Verdict: healthy boundary, questionable mechanism.** The line (network config in android, URL contract in common) is right; the wiring (mutable global singleton + implicit `init` side-effect + silent `""` default) is the smell. On iOS resolver stays `{ "" }` forever (deferred debt). Recommended fix IN-MR: drop silent `""` default → fail-fast on uninitialized + narrow setter visibility.

**Seam-scaling risk for Phase 2-3 (the load-bearing long-term concern):** `object{var resolver}` is tolerable as ONE case but must NOT become the pattern for every common↔android "accidental" link, or Phase 3 ends up with a scatter of mutable global singletons with implicit init order. Phase-2 plan should fix a policy: platform values reach common via ONE canonical mechanism (expect/actual OR DI param); ApiUrlProvider is a Phase-1 one-off exception, not a template. Also pin ADR: androidx.lifecycle.ViewModel IS the chosen common VM contract (don't build a parallel expect/actual VM abstraction).

**Dependency direction:** clean, no cycle. viewmodel(common) ─api→ presentation:error(common) → data:source:error(common) → response/serialization(common) → network:utils(common, ApiUrlProvider). network:utils has 0 deps so cycle impossible. Topology preserved 1:1 from the prior androidMain layout — the move only re-homed source sets, didn't redirect edges.

**IOException contract:** GeneralApiException : kotlinx.io.IOException (actual typealias java.io.IOException on Android) — byte-compatible with ~193 catch(IOException) + OkHttp interceptors. Correct (NOT Throwable).

**Spec gap at review time:** `docs/specs/2026-06-15-feature-ui-kmp-split.md` was physically ABSENT in the worktree — only `feature-ui-kmp-split-nav-contract.md` present. AC verified against nav-contract only; AC-13 unverifiable. Source of truth for /acceptance was incomplete — flag before promotion.
