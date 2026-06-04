---
name: zero-overhead-design-rule
description: BigNumKt's core perf constraint — every arithmetic op delegates to the platform primitive with only wrapper-allocation overhead; no pure-Kotlin reimplementation
type: project
---

BigNumKt's design philosophy (project CLAUDE.md) mandates **zero-overhead delegation to platform primitives**: every arithmetic op delegates to `java.math.BigDecimal`/`BigInteger` on JVM and `NSDecimalNumber` on Apple. Wrapper allocation is the ONLY acceptable overhead. Never reimplement arithmetic, never add a pure-Kotlin common fallback. The rationale: it must be a drop-in replacement for code that already trusts `java.math.BigDecimal`, with no measurable regression.

**Why:** the library's whole value proposition is letting Kotlin codebases move `java.math.BigDecimal` usage from `jvmMain` to `commonMain` with a near-mechanical migration and no perf cost. A measurable regression breaks the pitch.

**How to apply:** any Apple/native-side change that adds per-op work (e.g. the overflow guard, see [[apple-overflow-guard-hotpath]]) is in tension with this rule and must be justified against it. The acceptance criterion AC-CLS-4 phrases it as "no measurable overhead beyond noise floor." When grading such changes: JVM path must stay literally zero-overhead (the guard is appleMain-only — JVM is untouched, which is correct); Apple path gets latitude because the alternative (process SIGABRT on overflow) is worse than a small overhead. Simulator numbers overstate ObjC-dispatch cost vs device — flag that any Apple per-op % is an upper bound until device-measured.
