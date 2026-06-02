---
name: agp9-built-in-kotlin-impl-artifact
description: AGP 9 built-in Kotlin plugin impl coordinate + why convention plugins need it on their own classpath
type: project
---

AGP 9 built-in Kotlin plugin (`com.android.built-in-kotlin`, renamed from `com.android.experimental.built-in-kotlin` in 9.0) impl artifact is **`com.android.tools.build:gradle-kotlin`**, version = AGP version. Confirmed from the marker POM `com.android.built-in-kotlin:com.android.built-in-kotlin.gradle.plugin:<v>` whose sole `<dependency>` is `com.android.tools.build:gradle-kotlin`.

**Why:** This impl artifact is NOT pulled in by `com.android.tools.build:gradle`. When a convention plugin applies the id from inside its own `apply()` (`project.pluginManager.apply("com.android.built-in-kotlin")`), the impl class must be on the convention plugin's **runtime classpath** (the `dependencies {}` block of the convention plugin's build.gradle.kts, e.g. `android-base-gradle-plugin`). The plugin-marker only helps the `plugins {}` DSL, not `apply(id)`. The top `buildscript {}` classpath governs only compilation of that build file — do NOT add it there (cargo-cult, breaks minimal-diff).

**How to apply:** In `android-base-gradle-plugin`, declared via catalog entry `androidBuiltInKotlin = { module = "com.android.tools.build:gradle-kotlin", version.ref = "agp" }` (reuses `agp` version ref) + `implementation(libs.androidBuiltInKotlin)`. Use `implementation`, not `api` — applied by id, types never leak into the plugin's public surface. This mirrors exactly why `apply("com.android.library")` already works (gradle jar on runtime classpath via `api(libs.androidGradlePlugin)`).

Global flag `android.builtInKotlin=false` stays as-is during phased migration; per-module `apply("com.android.built-in-kotlin")` opts in regardless. AGP emits `WARNING: The option setting 'android.builtInKotlin=false' is deprecated` — expected, not a blocker. See [[agp9-migration-state]].
