# Per-stack composition, reference implementations, fast-moving UI

## Three channel roles

They complement each other and are often needed in parallel:

- **API truth** (signatures, semantics, types, alternatives) — always, when writing or editing
  code against a library.
- **Guides** (recommended patterns, migration, codelabs, troubleshooting, "how it's done") —
  for "how do I do X", "migrate A→B", an unfamiliar stack, a non-trivial integration.
- **Project style & versions** (conventions, pinned versions, wired modules) — always, as a
  separate pass on top of the external channels. This is **not** API truth.

`→` below means a fallback *within* one role, not a priority *between* roles. Memorised
signatures are never a source.

## Composition by stack

API truth and guides run in parallel when the task is non-trivial.

- **Android:** API truth = `ksrc` + `android docs` in parallel (the jar and the current
  recommendation, not either/or). Guides = `android docs` + bundled Android CLI skills in
  parallel. Fallback: Context7 → WebSearch.
- **JVM/Kotlin/KMP/Gradle (non-Android):** API truth = `ksrc` primary → Context7 → WebSearch.
  Guides = Context7 (Kotlin coverage is uneven) → WebSearch. `ksrc` gives only sources — "how
  it's done" needs a second channel.
- **Frontend/JS/TS:** both roles — Context7 primary → WebSearch.
- **Other (Python/Go/Rust/C#/Swift…):** both roles — Context7 → WebSearch; plus the ecosystem's
  `ksrc` equivalent where one exists.

**High-staleness — both channels mandatory:** Ktor 3.x, Room (KMP `@Upsert`, multiplatform),
SQLDelight, kotlinx.serialization, kotlinx.datetime, Hilt, Koin, Compose Multiplatform,
Compose Material3, AGP 8+/9, KSP, Firebase Android (BoM v34+ dropped KTX), Navigation 3.

## Reference implementations — real code as the "how" source

Before a non-trivial feature or integration, look for reference code **proactively**, on a par
with the docs. Current real code is often **stronger than docs** for the *guides* role — how
to actually wire X: DI, config boilerplate, layer and pattern organisation. For *API truth*
(signatures) it stays supporting; `ksrc` and official sources remain T1.

**Two classes, different trust and different search:**

- **Stack samples** (matching the project's framework/stack), vendor-endorsed → **T1/T2**:
  `android/nowinandroid`, `android/compose-samples`, `android/architecture-samples`,
  `JetBrains/compose-multiplatform` examples, Apple
  `developer.apple.com/tutorials/sample-apps` / `pointfreeco/isowords`, `shadcn-ui/taxonomy`.
- **Domain OSS** — a popular open-source app in the **same domain** (a messenger when building
  a messenger, notes for notes) → **T3**: someone else's intent, may carry team conventions or
  anti-patterns. Never the sole source; cross-check against API truth.

**Discovery:** vendor-endorsed beats everything else. After that: commit freshness and release
cadence, issue dynamics, "used by", maintainer/organisation reputation — **not bare stars**
(they are gamed). At domain level: GitHub topics (`sample-app`, `reference-architecture`),
awesome-lists, searching `"{domain} app {language} open source architecture"`. Besides finding
a whole reference repo, targeted **usage search across code** is available when you need an
example of one specific call or pattern rather than a whole architecture — see
`oss-channels.md`.

**Guardrails:**
- **Point, don't embed** — reference the repo and file (`owner/repo` plus path); do not copy
  code into rules or context. Otherwise it goes stale and bloats context.
- **Version proximity** — the reference's stack version should be close to the project's;
  otherwise there is a deprecated-path risk, so downweight it.
- **Usage slice** — one repo is one way of using the thing, not a specification. Cross-check
  against T1/T2 API truth before porting a pattern.

## Fast-moving declarative UI — guides and changelog before implementing

For **Jetpack Compose, Compose Multiplatform (CMP), and SwiftUI**, "verify the API against the
version" is not enough: the stack moves fast, and besides *which API exists* you need *what is
currently recommended* — otherwise the code comes out dated (`NavigationView` instead of
`NavigationStack`, deprecated Compose APIs). Before implementing a non-trivial screen or
component in these stacks, cover three roles under the general discover → tier → cross-check
discipline:

**A. API truth — which API is actually in the project's version.** `ksrc` (T1, the real source
jar of the exact version; JVM/KMP → Jetpack Compose, CMP core/Material3; not Swift) → docs of
the same version number, or Context7 (T2). SwiftUI: the `apple-doc-mcp-server` MCP when
connected (T2; there is no ksrc equivalent for Apple).

**B. The recommended approach — how it's done now.** Official reference apps (code over docs,
T1/T2): `android/nowinandroid`, `android/compose-samples`,
`JetBrains/compose-multiplatform/examples`, Apple sample code → What's New / release notes /
roadmap (Android Dev Blog, JetBrains Kotlin Blog, WWDC) plus the design canon (Compose API
Guidelines, Material 3, Apple HIG) → community (T3/T4, **cross-check only, never the sole
source**): Swift Forums, Hacking with Swift / Sundell / Point-Free, Kotlin Slack, Android
Weekly.

**C. What changed and known issues.** `maven-mcp` `dependency-changes` — the changelog between
versions (T2; the richest signal for CMP). Issue trackers **at the right address**: Jetpack
Compose → **Google IssueTracker** (not GitHub); CMP → GitHub issues
(`JetBrains/compose-multiplatform`); SwiftUI → Apple Developer Forums / Feedback Assistant.

**Per-stack route:**
- **Jetpack Compose** → `android docs` CLI + developer.android.com release notes/BOM/roadmap +
  `ksrc`.
- **Compose Multiplatform** → core Compose tracks Jetpack Compose by **major.minor**
  (empirically: CMP 1.11.1 ↔ JC runtime 1.11.2 — the minor matches, the patch is its own; CMP
  ships later in calendar time). **But individual artifacts — Material3 and navigation
  (`org.jetbrains.androidx.navigation:navigation-compose`) — have their own numbering, and the
  KMP fork can lag androidx upstream** (e.g. KMP navigation 2.9.2 vs androidx 2.9.8), so check
  each artifact's version separately (maven-mcp plus the CMP GitHub release tables). For
  general Compose API, JC docs / `android docs` / `ksrc` at the same major.minor will do;
  JetBrains KMP docs, the Kotlin Blog, and GitHub release tables cover CMP specifics
  (iOS/Desktop/resources/`expect`-`actual`) and exact artifact version alignment.
- **SwiftUI** → `apple-doc-mcp-server` (primary when connected) plus Apple/WWDC; Apple's site
  is an SPA and raw WebFetch is unreliable, so prefer the MCP.
