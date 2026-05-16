---
name: library-verify
description: >-
  Verifies the current API of an external library before writing or editing code that uses it. Trigger when the user
  says "verify library", "check API for X", "before I write code with X", "what's the signature of X", "how to use X in
  version V", "is Y still in version V", "what changed in X version", or any time you are about to write code calling
  an external library symbol whose API you might be remembering from training data. The skill is an orchestrator that
  routes the lookup to the right channel (`ksrc`, `android docs search`, Context7, DeepWiki, WebSearch) depending on
  the stack, and reads existing project code in parallel for style and pinned versions. Do NOT use for: pure
  documentation reading without code intent (use Context7 directly); checking versions or CVEs (use maven-mcp skills);
  navigating the project's own code (use ast-index); refactoring or business logic debugging.
---

# library-verify

Cheap pre-flight check before Edit/Write of code that uses an external library. Two parallel channels with distinct
roles — API truth (sources of record) and existing project code (style + pinned versions). Memorized signatures are
never an acceptable source. Full rationale and high-staleness library list live in `~/.claude/CLAUDE.md → External
sources → Verify library API before code`.

## When to invoke

Before writing code that calls a third-party library symbol — class, function, builder, extension, annotation, DSL
entry point. Also invoke when the user asks "how does X work in version V" with the obvious follow-up of writing code.

Skip when: only reading docs without code intent (Context7 directly fits), only checking the latest version or CVE
status (the maven-mcp skills fit), or navigating the project's own code (ast-index fits).

## Step 1 — frame the lookup

State plainly to yourself:

- Library name + the specific operation, symbol, or migration you are about to use.
- Stack: `Gradle/JVM/Kotlin/KMP` | `Android Jetpack/Compose/AGP/SDK` | `Frontend JS/TS` | `Other`.
- If the stack is unclear, infer from build files (`build.gradle*`, `libs.versions.toml`, `package.json`, `Cargo.toml`,
  `pyproject.toml`, `go.mod`, `Package.swift`).

## Step 2 — API truth chain (pick by stack)

Try the channels in order. Stop at the first that yields a definitive signature. Never invent intermediate steps.

- **JVM / Kotlin / KMP / Gradle**: `ksrc search "<symbol>"` → if no hit → `Context7 resolve-library-id` + `query-docs`
  → if no hit → `DeepWiki ask_question` against the upstream public repo → WebSearch as last resort.
- **Android (Jetpack / Compose / AGP / SDK)**: `android docs search "<query>"` → `ksrc search` for the source jar →
  Context7 → DeepWiki.
- **Frontend / JS / TS / web framework**: Context7 → DeepWiki → WebSearch.
- **Other (Python / Go / Rust / C# / Swift / …)**: Context7 → DeepWiki → WebSearch; use the ecosystem analogue of
  ksrc if available.

`resolve-library-id` rule: one miss → stop on Context7 and move to the next channel; don't chase synonyms.

## Step 3 — existing code in parallel

Run alongside Step 2, not as a substitute:

- `ast-index search "<symbol>"` if the project is indexed (see `~/.claude/rules/ast-index.md` for init); otherwise
  Grep.
- Extract: pinned version, idiomatic usage pattern, surrounding architecture (DI, modules, naming).

Treat the result as style and version evidence only. If existing usage contradicts the API-truth channel, the
API-truth channel wins — but flag the contradiction in the summary so the user sees the gap.

## Step 4 — synthesize and proceed

Before the actual Edit/Write, surface one short block to the user:

- Symbol + signature (from API truth).
- Library version (from existing build files).
- Source channel that confirmed it.
- Any delta from existing project usage (deprecations, new alternatives, KMP-only forms, etc.).

If no API-truth channel returned a confirmed signature — stop. Report the gap to the user and ask. Do not guess.

## Anti-patterns

- Using ast-index for dependency jars — it indexes the project, not jars; ksrc reads jars.
- Using existing project code as the primary API source — it shows only one slice and may be legacy/anti-pattern.
- Retrying `resolve-library-id` with synonyms after one miss.
- Skipping the API-truth chain because "I know this API" — training data drifts; the high-staleness list in CLAUDE.md
  is the minimum trigger set, not the maximum.
- Running this skill on the project's own source — ast-index is the right tool there.
