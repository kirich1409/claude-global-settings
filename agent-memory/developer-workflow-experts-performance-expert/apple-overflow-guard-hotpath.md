---
name: apple-overflow-guard-hotpath
description: Performance profile of the Apple NSDecimalNumber overflow guard on the arithmetic hot path; where the residual cost lives and the pow-loop redundancy
type: project
---

The Apple actuals route every `plus`/`minus`/`times`/`divide`/`movePoint*` through `guarded {}` in `appleMain/.../OverflowGuard.kt`, which attaches a cached `NSDecimalNumberHandler` singleton (`arithmeticOverflowHandler`, top-level `val` — allocated once at class-init, not per-op) and then does a per-op `result.isEqualToNumber(NSDecimalNumber.notANumber)` sentinel check to detect exponent overflow (~10^127).

**Why:** native `NSDecimalNumber` raises `NSDecimalNumberOverflowException` which Kotlin/Native cannot catch — the process would SIGABRT. `raiseOnOverflow=false` converts the raise into a `notANumber` result that the sentinel check turns into a catchable `BigNumArithmeticException`. An earlier custom K/N `NSObject` + `NSDecimalNumberBehaviorsProtocol` subclass cost ~40% per op because `roundingMode()`/`scale()` consults crossed the ObjC→K/N bridge every op; the native handler keeps consults in ObjC-land and cut that to ~25-30% on simulator.

**Residual cost (simulator, iosSimulatorArm64):** cheap ops +25-30% (~150 ns/op), divide +3% (noise). Attributed to the per-op `isEqualToNumber` sentinel call + wrapper allocation. divide's +3% is the tell: the absolute guard cost is small relative to real arithmetic, so it disappears proportionally as the underlying op gets heavier. On device (baseline ~2-5 µs/op vs simulator ~0.5 µs) the same absolute ~150 ns would be 3-8% — but this is extrapolated, not measured.

**pow-loop redundancy (real, unfixed):** `pow(n)` is a `repeat(n-1) { result = result.times(this) }` loop where every `times` runs `guarded`, so N-1 sentinel checks. `notANumber` propagates (NaN×x=NaN), so only the FINAL result needs checking — intermediate checks are redundant for correctness. Saves (N-2) `isEqualToNumber` calls per pow. Win scales with exponent; negligible for pow(2-3), meaningful for large N. Does NOT change immediate-throw semantics (final check still throws on the same op).

**How to apply:** when reviewing Apple-side arithmetic perf, the guard is the known overhead source. The pow redundant-check elimination is the one concrete optimization on the table. Do not propose deferring overflow detection to point-of-observation — it breaks immediate-throw ACs (AC-T1-1/T1-6). The zero-overhead rule (see [[zero-overhead-design-rule]]) is the bar this is measured against.
