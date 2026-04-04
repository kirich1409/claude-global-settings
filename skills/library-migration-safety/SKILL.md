---
name: library-migration-safety
description: Use when replacing one library with another that serves the same purpose but has incompatible API — dates, networking, serialization, crypto, images, etc. Use when you need to guarantee behavioral equivalence after the swap and cannot afford silent regressions.
---

# Library Migration Safety

## Overview

**Core principle:** Migration changes the technology, not the behavior. The application must work exactly as before — including any existing bugs. Bugs found during migration are flagged to the developer; fixing them is a separate decision, separate commit, separate ticket.

**Test principle:** Tests must capture the OLD library's behavior BEFORE you change a single line of production code. Only then can they prove the new library behaves identically.

**Verification gate:** The same set of checks runs before migration starts, after behavioral tests are written, after each migration step, and after cleanup. If the gate is red at any point — stop and fix before continuing.

## The Process

```
Phase 0: ALIGN → Phase 1: CAPTURE → Phase 2: MIGRATE → Phase 3: VERIFY → Phase 4: CLEANUP
             ↓              ↓                  ↓                ↓                ↓
         [gate ✓]       [gate ✓]           [gate ✓]        [gate ✓]         [gate ✓]
```

### Verification Gate (runs at every phase transition)

Three checks, adapted to your project's toolchain:

| Check | What to run |
|-------|-------------|
| Unit tests | `./gradlew test` / `npm test` / `swift test` / `pytest` |
| Build | `./gradlew assemble` / `npm build` / `xcodebuild` / `cargo build` |
| Static analysis | `./gradlew detekt` / `eslint` / `swiftlint` / `clippy` |

All three must be green. If any is red — fix it before proceeding to the next phase. Do not start migration on a red project.

---

### Phase 0: ALIGN — discuss strategy with the developer before writing any code

**0.0 Run the verification gate.** Establish that the project is green BEFORE touching anything. If it's already red — fix it now or stop the migration. You cannot prove migration correctness on a broken baseline.

**0.1 Measure the scope of impact**

Before choosing strategy or splitting work, understand what is actually affected.

```bash
# Find direct call-sites
ast-index usages "OldClassName"       # how many places use the old type directly
ast-index usages "old.lib.OldClass"   # same with full qualified name

# Find affected modules
ast-index deps "module-name"          # which modules depend on the module being migrated
grep -r "import old.library" --include="*.kt" -l | sort -u   # adjust --include for your language: *.ts, *.swift, *.py, *.java
```

Classify the scope:

| Level | Signal | Implication |
|-------|--------|-------------|
| **Low** | ≤10 call-sites, 1 module, type not in public API | Single PR, unit tests only |
| **Medium** | 10–50 call-sites, 1–3 modules, type in public API of ≤1 module | Split by module, unit + integration |
| **High** | 50+ call-sites, 4+ modules, type propagates through public APIs | Split by stage (capture / migrate / cleanup), full QA checklist |
| **Critical** | Core infrastructure, data persistence, cross-platform, external API contract | Shadow or feature-flag, cannot merge until divergence = 0 |

Also identify which surfaces the old type touches — each surface adds required test types:

| Surface | Required additional test |
|---------|--------------------------|
| Persisted data (DB, files, prefs) | Backward compat test: write old → read new |
| Network / external API contract | Wire format snapshot test |
| UI / display | Visual output assertion |
| Cross-platform (iOS + Android, mobile + backend) | Platform-specific behavior tests on each platform |
| Serialization boundary (JSON, proto, Parcel/NSCoding) | Roundtrip test with real serializer |

Document scope level and surfaces in the PR description. This drives the PR split strategy in 0.3.

**0.2 Can the old and new libraries coexist in the build simultaneously?**

| Answer | Implication |
|--------|-------------|
| Yes — both can be in the build at once | Compatibility or Shadow strategy available |
| No — conflict, same package names | Must use Adapter or Direct strategy |

**0.3 Choose a strategy, agree on PR split:**

| Strategy | When to use | How it works |
|----------|------------|--------------|
| **Direct** | Low scope, can't coexist | Replace everything at once in one commit |
| **Adapter** | Medium/High scope, can't coexist | Wrap old API → migrate call-sites → swap implementation |
| **Compatibility** | Any scope, can coexist | Add new methods alongside old; migrate call-sites gradually; remove old last |
| **Shadow** | Critical scope, high risk | Run both implementations in parallel; compare outputs; cut over when confident |

**PR split strategy by scope level:**

| Scope | PR strategy | Gates required |
|-------|-------------|----------------|
| **Low** | Single PR: capture tests + migrate + cleanup | Gate after each commit |
| **Medium** | 1 PR per module; or: PR-1 capture+migrate, PR-2 cleanup | Gate between PRs |
| **High** | PR-0: introduce seam/adapter first if needed (this is the split point); PR-1: capture tests (all modules); PR-N: one module per PR; PR-last: cleanup | Gate between every PR; each PR mergeable independently |
| **Critical (Shadow)** | PR-1: shadow mode + interface seam; PR-2+: module-by-module under shadow; PR-last: cut over + remove shadow | Cannot merge without zero divergences in shadow logs |
| **Critical (Adapter)** | PR-0: introduce interface seam; PR-1: capture tests; PR-N: one module per PR; PR-last: remove old dependency | Gate between every PR |

> **High/Critical:** if splitting seems impossible, introduce the Adapter/Interface Seam first (PR-0). The seam is the split point — each subsequent PR migrates one module independently behind it.

**Which techniques to use per strategy:**

| Strategy | Techniques |
|----------|------------|
| Direct | — (replace in-place) |
| Adapter | Facade (5), Conversion Pair (2) at boundaries |
| Compatibility | Compatibility Overloads (4) or Deprecation Ladder (3) |
| Shadow | Interface Seam (6), optionally Leaf-First Ordering (7) |

Document the agreed strategy in the PR description before starting.

**0.4 Full technique descriptions** — see [Migration Techniques Catalog](#migration-techniques-catalog) below.

---

### Phase 1: CAPTURE — lock behavior before touching production code

**1.1 Find all call-sites**

```bash
ast-index usages "OldClassName"
# or
grep -r "import old.library" --include="*.kt" -l  # adjust --include for your language: *.ts, *.swift, *.py, *.java
```

**1.2 Catalog unique usage patterns** (not files — patterns)

Group call-sites by what they do, not where they live:

| Pattern | Example | Edge cases to cover |
|---------|---------|---------------------|
| Parse string → object | `sdf.parse("01.01.2024")` | Invalid input, wrong format, boundary values |
| Format object → string | `sdf.format(date)` | Locale, zero-padding, year boundaries |
| Arithmetic | `date.time + days * 86400000L` | DST transitions, leap days, negative values |
| Comparison / range | `date.before(other)` | Equal dates, reversed order |
| Serialization roundtrip | JSON encode/decode, Parcelable | Null, special characters, epoch |

**1.3 Write behavioral tests against the OLD API**

Tests target behavior, not implementation. The signature uses the OLD types:

```kotlin
// DateFormatterBehaviorTest.kt — written BEFORE migration
// Uses java.util.Date intentionally — this is the contract we're locking

class DateFormatterBehaviorTest : FreeSpec({
    "parse then format is identity" {
        val original = "05.03.2024"
        val parsed = DateFormatter.parse(original)   // returns java.util.Date
        DateFormatter.format(parsed) shouldBe original
    }
    "addDays crosses month boundary" {
        val jan30 = DateFormatter.parse("30.01.2024")
        DateFormatter.addDays(jan30, 3) shouldBe DateFormatter.parse("02.02.2024")
    }
    "parse throws on invalid input" {
        shouldThrow<IllegalArgumentException> { DateFormatter.parse("not-a-date") }
    }
})
```

**1.4 If you discover a bug — flag it, don't fix it**

```kotlin
// BUG FOUND (not fixed): SimpleDateFormat is not thread-safe — shared mutable state.
// Flagged to developer. Fix separately after migration is complete.
// See: JIRA-5678
private val sdf = SimpleDateFormat("dd.MM.yyyy", Locale.getDefault())
```

Write the comment, note the ticket, move on. Do not fix it in the migration commit.

**→ Run the verification gate.** New tests must be green against the old library. If a test fails here — fix the test (not the code). You're documenting reality, not wishful behavior.

---

### Phase 2: MIGRATE — replace the implementation

Apply the strategy agreed in Phase 0. Run the verification gate after each meaningful commit — do not accumulate multiple commits before checking.

> **What counts as a meaningful commit:** any commit that (a) compiles, (b) all existing tests still pass, and (c) completes one self-contained step: introduce the adapter, migrate one module, swap the facade implementation, or remove the old overload. Do not combine steps in one commit. If in doubt, commit more often.

**Direct strategy (small scope, can't coexist):**

Replace old types in-place. Update test type signatures to match new types, but keep all assertions identical. Do it in one atomic commit that includes: dependency changes in `build.gradle.kts`, all call-site updates, and test signature updates.

**Adapter strategy (large scope, can't coexist):**

```kotlin
// Commit 1: introduce facade backed by old library
// All call-sites point here — gate must be green after this commit
object DateUtils {
    fun parse(s: String): Date = OldLib.parse(s)
    fun format(d: Date): String = OldLib.format(d)
}

// Commit 2: migrate all call-sites to DateUtils
// Old library still in use underneath — gate must be green

// Commit 3: swap facade implementation + update test type signatures
// Tests keep the same assertions; only type annotations change
object DateUtils {
    fun parse(s: String): LocalDate = NewLib.parse(s)
    fun format(d: LocalDate): String = NewLib.format(d)
}
// → Run verification gate
```

**Compatibility strategy (can coexist, gradual migration):**

```kotlin
// Add new methods alongside old — both live in the codebase simultaneously
object DateFormatter {
    // OLD — kept until all call-sites migrate
    fun format(date: Date): String = OldLib.format(date)

    // NEW — delegates to new library
    fun format(date: LocalDate): String = NewLib.format(date)
}

// While both exist, tests can verify equivalence live:
val legacyDate: Date = OldLib.parse("05.03.2024")
val localDate: LocalDate = LocalDate(2024, 3, 5)

"old and new format produce identical output" {
    DateFormatter.format(legacyDate) shouldBe DateFormatter.format(localDate)
}
```

Remove the old overload only after all call-sites have moved to the new one.

**Shadow strategy (critical path, high risk):**

```kotlin
// Run both implementations in parallel; use old result in production
fun parse(s: String): Date {
    val oldResult = OldLib.parse(s)
    val newResult = runCatching { NewLib.parse(s) }

    // Log divergences — don't fail production
    if (newResult.isSuccess && newResult.getOrNull().toString() != oldResult.toString()) {
        logger.warn("Shadow divergence for '$s': old=$oldResult new=${newResult.getOrNull()}")
    }

    return oldResult  // old result used until shadow is verified clean in production
}
// After zero divergences → cut over → remove shadow
```

**Intentional exceptions** — if something cannot be migrated now, mark it explicitly:

```kotlin
// MIGRATION-EXCEPTION: SafeArgs generates java.util.Date in NavArgs until SafeArgs 2.9
// Tracked: JIRA-1234. Remove after SafeArgs upgrade.
import java.util.Date
```

No comment = not allowed.

**If the gate turns red and you cannot fix it quickly** (within the same working session): revert the last commit, return to the last known-green state, and investigate the cause in isolation. Do not accumulate broken commits — each one makes the next fix harder to reason about.

```bash
git revert HEAD      # safe: creates a new revert commit
# or
git reset HEAD~1     # removes the last commit; unstaged changes remain
```

---

### Phase 3: VERIFY — confirm behavioral equivalence

**Run the verification gate:**

```bash
# 1. All behavioral tests green (same tests from Phase 1, updated signatures)
./gradlew :module:testDebugUnitTest

# 2. No old library imports remain in scope
grep -r "import old.library" path/to/module --include="*.kt"  # adjust --include for your language
# → must return nothing (or only MIGRATION-EXCEPTION lines)

# 3. Build and static analysis clean
./gradlew :module:assembleDebug
./gradlew :module:detekt
```

All three pass → proceed to Phase 4.

---

### Phase 4: CLEANUP — remove migration scaffolding

Migration tests are scaffolding. Once migration is verified, delete them. Leaving them creates false safety: they will pass forever regardless of future regressions because the library is already replaced.

**For each test written in Phase 1, ask:**

> Would this test catch a bug in *our* code if someone changed *our* logic — regardless of which library is underneath?

| Answer | Action |
|--------|--------|
| Yes — tests our logic, not the library | Keep. Move to the permanent test suite. |
| No — only verified the library swap | Delete. |

**Tests to delete vs keep:**

```kotlin
// DELETE — only verified that the new library parses dates correctly
it("parses 01.01.2024 correctly") {
    DateFormatter.parse("01.01.2024") shouldBe LocalDate(2024, 1, 1)
}

// KEEP — tests our business rule: display date must match parsed date
it("displayDate in Transaction equals the original dateStr") {
    mapTransaction(TransactionDto(dateStr = "17.09.2023")).displayDate shouldBe "17.09.2023"
}

// DELETE — tests the compatibility bridge, not business logic
it("old and new format produce identical output for 05.03.2024") { ... }
```

**What makes a migration test useless (delete these):**

| Category | Example | Why useless |
|----------|---------|-------------|
| **Tests the language** | `data class` equality, `rangeTo`, `copy()` | The language guarantees it |
| **Tests a third-party library** | `LocalDate.fromEpochDays(x.toEpochDays()) == x` | Tests their code, not ours |
| **Tests the mechanism, not the result** | `result.time shouldBe date.time + 86_400_000L` | Asserts HOW, not WHAT |
| **Hedged assertion** | `assert(x in -1..0)` when both are "ok" | Contract is undefined |
| **Tests only the sign** | `assert(days > 0)` | `Int.MAX_VALUE` would pass |
| **Name promises X, body tests Y** | "Parcel roundtrip" but tests `data class equals` | False confidence |

**The test quality bar:** every remaining test must catch a plausible bug in our logic. If you cannot name a specific bug the test would catch, delete it.

**Remove the old library from your build file** only after all three conditions are met:
1. No old imports remain (or only explicitly commented MIGRATION-EXCEPTION lines)
2. All migration scaffolding tests are deleted or promoted to the permanent suite
3. The verification gate is green without the old dependency

Do not remove the dependency earlier — keeping it while you clean up lets the compiler enforce that MIGRATION-EXCEPTION lines are the only remaining usages.

**→ Run the verification gate one final time.**

Migration is complete when: gate is green AND scaffolding is removed AND old dependency is removed from build files.

---

## Migration Techniques Catalog

Use this catalog in Phase 0 to select specific techniques. Strategies are combinations of techniques.

---

### Technique 1: Type Alias Bridge

**Use when:** New type is structurally identical or a drop-in for the old one.

```kotlin
// Instantly fixes all compilation errors with zero behavioral change
typealias Date = kotlinx.datetime.LocalDate
```

**Scale:** Any. Fastest first step when types align. Remove the alias once all call-sites are updated.

**Works for:** Date/time types, primitive wrappers, sealed class hierarchies with same shape.

---

### Technique 2: Conversion Pair (toNew / toOld)

**Use when:** Types differ but can be converted. Migration happens module by module at boundaries.

```kotlin
fun Date.toLocal(): LocalDate = LocalDate.fromEpochDays((time / 86_400_000L).toInt())
fun LocalDate.toLegacy(): Date = Date(toEpochDays() * 86_400_000L)

// Module A (not yet migrated) calls Module B (already migrated):
val localDate = moduleB.getSomething()
val legacyDate = localDate.toLegacy()  // bridge at the seam
```

**Scale:** Medium to large. Migrate one module at a time without touching the others.

**Works for:** Any two types that map to the same domain concept (Date↔LocalDate, Response↔Result).

---

### Technique 3: Deprecation Ladder

**Use when:** Libraries can coexist, many scattered call-sites, gradual team migration over time.

```kotlin
@Deprecated(
    message = "Use format(LocalDate) instead",
    replaceWith = ReplaceWith("format(date.toLocal())", "com.example.ext.toLocal"),
    level = DeprecationLevel.WARNING   // WARNING → ERROR → remove, over multiple releases
)
fun format(date: Date): String = format(date.toLocal())  // delegates to new implementation

fun format(date: LocalDate): String = newPattern.format(date)  // canonical implementation
```

IDE shows the exact replacement at every call-site. Migrate them one by one.

**Scale:** Large, gradual. No big-bang risk.

**Works for:** Utility functions, formatters, extension functions with many scattered usages.

---

### Technique 4: Compatibility Overloads

**Use when:** Libraries can coexist, you want both APIs simultaneously so tests can compare them directly.

```kotlin
object DateFormatter {
    fun format(date: Date): String = OldLib.format(date)          // old
    fun format(date: LocalDate): String = NewLib.format(date)     // new
}

// Tests verify equivalence while both exist — both must produce identical output
"old and new format produce identical output" {
    val legacyDate: Date = OldLib.parse("05.03.2024")
    val localDate: LocalDate = LocalDate(2024, 3, 5)
    DateFormatter.format(legacyDate) shouldBe DateFormatter.format(localDate)
}
```

*Difference from Technique 3:* No deprecation — both are first-class. Technique 3 is for a graduated timeline (WARNING→ERROR→remove). Technique 4 is for running both simultaneously to verify equivalence.

**Scale:** Medium.

**Works for:** Formatting, parsing, serialization — anywhere overload resolution can distinguish old from new by type.

---

### Technique 5: Facade / Adapter Object

**Use when:** Libraries cannot coexist, or you want a single point of control over the entire migration.

```kotlin
// Commit 1: introduce facade — all call-sites migrate here, old lib still underneath
object Dates {
    fun parse(s: String): Date = OldLib.parse(s)
    fun format(d: Date): String = OldLib.format(d)
}
// → gate ✓

// Commit 2: all call-sites now use Dates.X — gate must be green

// Commit 3: swap implementation + update test type signatures
object Dates {
    fun parse(s: String): LocalDate = NewLib.parse(s)
    fun format(d: LocalDate): String = NewLib.format(d)
}
// → gate ✓
```

**Scale:** Any. The more call-sites there are, the more valuable the single swap point.

---

### Technique 6: Interface Seam

**Use when:** Library is injected via DI, you need shadow comparison, or you need to swap in tests.

```kotlin
interface DateParser {
    fun parse(s: String): LocalDate
    fun format(d: LocalDate): String
}

class LegacyDateParser : DateParser { /* wraps old lib */ }
class ModernDateParser : DateParser { /* uses new lib */ }

// Inject via DI — swap implementation without touching call-sites
```

**Scale:** Large. Required for Shadow strategy.

**Works for:** Networking clients, serializers, image loaders, crypto — any library surfaced through DI.

---

### Technique 7: Leaf-First Module Ordering

**Use when:** Library is used across many modules in a dependency tree.

```bash
ast-index deps "module-name"  # identify dependency order
```

Migrate leaves first (most isolated), root last:

```
:new-core:date-utils     ← migrate first (no dependents within scope)
    ↑
:feature:transactions    ← migrate second
    ↑
:app                     ← migrate last
```

Each migrated module becomes a clean boundary. Run the gate after each module.

**Scale:** Large multi-module projects.

---

### Technique 8: Seam at Module API Boundary

**Use when:** Module has a clear `api/` / `internal/` split.

```
Step 1 — change api/ types (what consumers see):
  api/Gateway.kt:          fun getDate(): LocalDate   ← updated
  internal/GatewayImpl.kt: return oldLib.date.toLocal()  ← convert at boundary
  → gate ✓

Step 2 — replace internal/ implementation:
  internal/GatewayImpl.kt: return newLib.date()   ← no conversion needed
  → gate ✓
```

**Scale:** Any modular project with well-defined boundaries.

---

### Quick Reference

| Situation | Recommended technique(s) |
|-----------|--------------------------|
| Types are structurally identical | Type Alias Bridge (1) |
| Types differ, migrate module by module | Conversion Pair (2) |
| Many scattered call-sites, gradual migration | Deprecation Ladder (3) |
| Can coexist, want parallel equivalence testing | Compatibility Overloads (4) |
| Can't coexist, want single swap point | Facade / Adapter Object (5) |
| DI injection, shadow mode needed | Interface Seam (6) |
| Many modules, type propagates through tree | Leaf-First Ordering (7) |
| Clear api/ / internal/ split | Seam at API Boundary (8) |

Techniques compose: a large migration typically uses Leaf-First Ordering (7) to sequence work, Facade (5) per module, and Conversion Pair (2) at each module boundary.

---

## What the Baseline Agent Gets Wrong

| What agents naturally do | What you must do instead |
|--------------------------|--------------------------|
| Start migration on a red project | Run gate first; establish green baseline |
| Skip scope measurement | Count call-sites, modules, surfaces (Phase 0.1) before choosing strategy |
| Put everything in one PR | Split by scope: Low=1 PR, Medium=per module, High=per stage, Critical=shadow |
| Write tests for new API first | Write tests for old API first, run gate |
| Work with files mentioned in the task | Find ALL call-sites with ast-index/grep |
| Test happy path only | Identify domain-specific edge cases per pattern |
| Accumulate multiple commits before verifying | Run gate after each meaningful commit |
| Check "it compiles" | Check "no old imports remain" explicitly |
| Skip lint | Run detekt as part of the gate |
| Leave unexplained old imports | Either migrate or add MIGRATION-EXCEPTION comment |
| Fix bugs found during migration | Flag to developer with comment; don't fix in migration commit |
| Pick a strategy unilaterally | Agree strategy with developer in Phase 0 before writing code |
| Keep all migration tests permanently | Delete scaffolding in Phase 4; keep only tests of our own logic |

## What Unit Tests Don't Cover — QA-Proof Checklist

Unit tests verify logic in isolation. These categories require additional coverage and are the most common sources of post-migration bugs reported by QA.

### 1. Persisted data backward compatibility

**Risk:** A user has data stored with the old library's format (Room DB, SharedPreferences, file). After migration, the app cannot read it.

**How to test:** Write a test that creates data using the OLD library's serialization, then reads it using the NEW library's deserialization. This test must exist before you delete the old library from dependencies.

```kotlin
@Test fun `room migration: date stored as Long is readable as LocalDate`() {
    // Simulate what was stored by old code (using old library's serialization)
    val legacyEpochMs = SimpleDateFormat("dd.MM.yyyy", Locale.ROOT).parse("05.03.2024")!!.time
    db.insertRaw(legacyEpochMs)

    // Verify new code can read it
    val entity = db.getLatest()
    entity.date shouldBe LocalDate(2024, 3, 5)
}
```

Run these as instrumented tests (`connectedAndroidTest`), not unit tests — Room behavior differs on JVM.

### 2. Wire format / backend contract

**Risk:** The library changes how it serializes data sent to or received from the backend. A date that was `"2024-03-05"` becomes `"2024-3-5"`. The server returns 400.

**How to test:** Capture the exact serialized string before migration, assert it's identical after:

```kotlin
@Test fun `date serializes to ISO format expected by backend`() {
    val date = LocalDate(2024, 3, 5)
    val json = Json.encodeToString(date)
    json shouldBe "\"2024-03-05\""  // exact string the backend expects
}
```

If you don't have an integration test environment, add this as a unit snapshot test. The assertion is the wire format, not the semantic value.

### 3. Locale and timezone sensitivity

**Risk:** Tests pass with the CI machine's locale (`en_US`). On a user's device with a different locale or timezone, formatting differs or parsing fails.

**How to test:** Run behavioral tests with multiple locale/timezone configurations:

```kotlin
// Run the same test suite under different locales
listOf(Locale("be", "BY"), Locale("ru", "RU"), Locale.US).forEach { locale ->
    Locale.setDefault(locale)
    DateFormatter.format(LocalDate(2024, 3, 5)) shouldBe "05.03.2024"
}

// And with explicit timezone (don't rely on system default in tests)
val tz = TimeZone.of("Europe/Minsk")
Clock.System.todayIn(tz) // use injected timezone, not system default
```

If your formatter uses `Locale.getDefault()` anywhere — that's a risk surface. Make locale explicit.

### 4. Property-based edge cases

**Risk:** Fixed test inputs pass. Real user input (unexpected characters, year 0, far-future dates, negative timestamps) breaks.

**How to test:** Use Kotest property testing to generate inputs across the full domain:

```kotlin
checkAll(Arb.localDate()) { date ->
    // round-trip must hold for ANY valid date, not just handpicked examples
    DateFormatter.parse(DateFormatter.format(date)) shouldBe date
}
```

Property tests catch: year 100, year 9999, Feb 29 on any leap year, dates before epoch, DST transition days.

### 5. Platform-specific serialization / runtime behavior

**Risk:** The type passes through a platform serialization mechanism (Android Parcel/Bundle, iOS NSCoding/Codable, React Native bridge, WebAssembly boundary). Unit tests on the host JVM/Node/simulator don't exercise the real runtime path and won't catch marshalling failures.

**Cover with real on-device / on-platform tests:**

| Platform | Serialization surface to test |
|----------|------------------------------|
| Android | Parcel/Bundle roundtrip, NavArgs, process death + restore |
| iOS | NSCoding / Codable roundtrip, `UserActivity` state restoration |
| React Native / Flutter | JS bridge serialization for types crossing the bridge |
| Backend | Framework serialization (Jackson, kotlinx.serialization, serde) with real request/response cycle |

```kotlin
// Android instrumented example
@Test fun `model survives Parcel roundtrip`() {
    val parcel = Parcel.obtain()
    model.writeToParcel(parcel, 0)
    parcel.setDataPosition(0)
    val restored = MyModel.CREATOR.createFromParcel(parcel)
    restored shouldBe model
}
```

### 6. Visual regression (display output)

**Risk:** The value is correct but displays differently on screen — different number separators, changed date order, different rounding of amounts.

**How to test:** Screenshot-based verification for any screen that renders a value from the migrated library. Run UI tests before and after migration, compare screenshots. Alternatively: add end-to-end assertions on rendered text.

```kotlin
// After migration, verify text displayed on screen matches expected format
onView(withId(R.id.date_label)).check(matches(withText("05.03.2024")))
```

---

### Test Coverage Checklist Before Closing Migration

Use scope level from Phase 0.1 to determine which rows are required:

| Coverage area | Test type | Low | Medium | High | Critical |
|---------------|-----------|-----|--------|------|----------|
| Behavioral logic (Phase 1) | Unit | ✓ | ✓ | ✓ | ✓ |
| Locale / timezone sensitivity | Unit with explicit locale | — | ✓ | ✓ | ✓ |
| Property-based edge cases | Property test | — | ✓ | ✓ | ✓ |
| Wire format / API contract | Snapshot unit | — | if surface | ✓ | ✓ |
| Persisted data backward compat | Integration / on-device | — | if surface | ✓ | ✓ |
| Platform-specific serialization | On-device / instrumented | — | if surface | ✓ | ✓ |
| Visual display (if type renders on screen) | UI / screenshot | — | — | ✓ | ✓ |
| Shadow divergence = 0 in production | Shadow logs | — | — | — | ✓ |

Do not close the migration until the relevant rows for your scope level are green.

---

## Domain Edge Cases by Library Type

- **Dates:** DST transitions, leap years (Feb 29), locale-dependent formatting, epoch boundaries, timezone conversions
- **Networking:** timeout behavior, retry semantics, error body parsing, header case sensitivity
- **Serialization:** null fields, unknown keys, numeric precision (Float vs Double), date format in JSON
- **Crypto:** encoding charset, padding mode, key format, exception types on invalid input
- **Images:** EXIF stripping, color profile, animated format support, OOM on large inputs
- **Generated code** (SafeArgs, KAPT/KSP): cannot be directly edited — use MIGRATION-EXCEPTION comment; track removal in a separate ticket

## Red Flags — Stop and Review

- [Phase 0] "The project has a few failing tests, I'll ignore them" → **Fix the baseline first or stop. You cannot prove correctness on a broken baseline**
- [Phase 1] "I'll write tests after migration to verify it works" → **Tests written after cannot prove behavioral equivalence**
- [Phase 1] "The code compiles, so it's correct" → **Different behavior can compile fine**
- [Phase 1] "I only saw 3 usages" → **Did you run ast-index/grep? There might be 12**
- [Phase 2] "I'll do several commits and check at the end" → **Run the gate after each meaningful commit**
- [Phase 3] "This import is just for a type alias" → **Add MIGRATION-EXCEPTION comment or remove it**
- [Phase 3] "Lint/detekt can wait" → **They are part of the gate. Not optional**
- [Phase 4] "I'll leave the migration tests in case they're useful" → **Scaffolding left behind becomes noise; delete it**
- [Any] "This bug is minor, I'll fix it while I'm here" → **Stop. Flag it, don't fix it. Migration ≠ refactoring**
- [Any] "I'll just pick the adapter strategy, it's the safest" → **Discuss with the developer in Phase 0. Strategy depends on coexistence and scope**
- [Phase 0] "I'll do it all in one PR, it's faster" → **Measure scope first. High/Critical scope must be split — a mega PR cannot be properly reviewed or safely rolled back**
- [Phase 0] "I counted 3 usages, it's Low scope" → **Did you check transitive impact? Does the type appear in a public API? Does it touch persistence or network?**
- [Phase 2] "I'll split it later if the PR is too big" → **Split before starting migration, not after. Splitting mid-migration is harder than splitting at the seam**
