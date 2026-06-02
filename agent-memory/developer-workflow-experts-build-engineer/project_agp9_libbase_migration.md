---
name: agp9-libbase-migration
description: Recipe for migrating android-only modules off the deprecated KMP combo (abm.kmp.androidLib) to pure-Android abm.android.libBase — validated by salary-project-impl pilot
type: project
---

AGP 9.2 migration: android-only modules move from `abm.kmp.androidLib` (com.android.library + kotlin-multiplatform, triggers `non-kmp-agp-is-deprecated`) to `abm.android.libBase` (AndroidBaseConfigurationPlugin → com.android.library + com.android.built-in-kotlin).

**Why:** AGP 9 deprecated the multiplatform+com.android.library combo. android-only modules (only `src/androidMain`, no commonMain/jvm/ios source) don't need KMP; moving them off the combo silences the per-module deprecation and is the batch target.

**How to apply (recipe, validated on salary-project-impl):**
1. Plugin: `alias(libs.plugins.abm.kmp.androidLib)` → `alias(libs.plugins.abm.android.libBase)`.
2. `android { }` block → `baseConfiguration { }` (extension class `BaseConfigurationExtensions`, in `android-base-gradle-plugin`). Field map:
   - `namespace = "..."` → `baseConfiguration { namespace = "..." }` (field is literally `namespace`; `packageId` is the app-style alternative the plugin falls back to for namespace — keep whichever the module already used, don't switch).
   - `buildFeatures { viewBinding = true }` → `useViewBinding = true`.
   - `androidResources.enable = true` → `useAndroidResources = true`. NOTE: plugin computes `useAndroidResources ?: useViewBinding`, so viewBinding alone already enables resources — setting it explicitly is 1:1 with original intent, harmless.
   - compileSdk/minSdk/targetSdk/buildToolsVersion have defaults from `ProjectConfig.android` — do NOT set unless the module overrode them.
3. `kotlin { sourceSets { commonMain.dependencies {...}; androidMain.dependencies {...} } }` → flat `dependencies { }`. Flatten BOTH source-set blocks into one `dependencies` block. Keep each dep's original config (`implementation` stayed `implementation`). Only use `api` if the module's own `-api` sibling is exposed (currency-contracts-impl pattern: `api(project(":x:x-api"))`); don't introduce `api` where the original had none.
4. Source layout: `git mv <module>/src/androidMain <module>/src/main` (one rename, preserves kotlin/ res/ AndroidManifest.xml + git history). libBase uses standard `src/main/kotlin` + `src/main/res` + `src/main/AndroidManifest.xml`. Verify no pre-existing `src/main` first.

**Reference module to copy the idiom:** `currency-contracts/currency-contracts-impl` (libBase + viewBinding + SafeArgs).

**Verify gates:**
- `:module:compileDebugKotlin --warning-mode all` → BUILD SUCCESSFUL; viewBinding class generated at `build/generated/data_binding_base_class_source_out/debug/.../databinding/*Binding.java`.
- The `non-kmp-agp-is-deprecated` warning may STILL appear in output even after migrating one module — it comes from OTHER still-KMP modules in the configuration graph, printed without module-context lines. Confirm it's not attributed to the migrated module (grep -B2 shows no module header before it).
- Consumer resolution (the real risk of KMP→pure-android variant-model change): compile one consumer. salary-project-impl's consumer = `apps:abm-android:common`; resolved cleanly via `bundleLibCompileToJarDebug`, no "No matching variant".
- STOP condition: if any consumer pulls the module from its `commonMain`/`iosMain` (not androidMain/main), that consumer needs the module to stay KMP — report, don't force.

**Surprise:** a single-target KMP module CAN have a `commonMain.dependencies` block with zero common SOURCE. That's still "android-only" — the deps are just declared in the common block but resolve to android variants. Flattening to `implementation` is a no-op semantically.
