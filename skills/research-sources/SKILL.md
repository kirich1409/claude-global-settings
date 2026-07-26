---
name: research-sources
description: >-
  Route a question to the right external source and weigh what comes back. Covers the
  source routing table (project code, ksrc, android docs, Context7, Claude Code harness
  docs, web, raw README),
  the discover-then-use-every-channel discipline, T1-T4 trust tiers and conflict
  resolution, per-stack API-truth composition, reference implementations, and
  open-source code-search channels.

  Use when: verifying a library API before writing code against it, "which version has
  this method", "how is X actually used", "find a reference implementation", "is this
  doc current", picking between conflicting sources, or gathering external information
  for research or a spec.

  Do NOT use for: navigating the project's own code (use ast-index / Explore), deciding
  whether to adopt a new dependency (use evaluate-dependency), or debugging your own logic.
---

# Research sources

Verifying an external API before writing code against it, and judging what the sources say.
Training data goes stale; existing project code shows only the slice of the API already in
use, which may be legacy or an anti-pattern.

| File | Covers |
|---|---|
| `references/stacks.md` | Per-stack API-truth and guides composition, reference implementations, fast-moving declarative UI |
| `references/oss-channels.md` | Open-source code-search channels, Context7 workflow |

## Routing

| Source | Use for | Not for |
|---|---|---|
| Local project code | First stop for questions about the project | — |
| `ksrc` | Reading JVM/Gradle dependency sources (the real source jar) | Project-internal code |
| `android docs search`/`fetch` | API truth + guides for Android/Jetpack/Compose/AGP/SDK | Non-Android libraries |
| `~/.android/cli/skills/**/SKILL.md` | Bundled Android CLI skills — structured workflows (migrations; Wear/XR/edge-to-edge/Compose styles/R8/Perfetto). Discovery: `android skills find <kw>` | API truth; non-Android tasks |
| Context7 | Docs for published libraries/frameworks, current API and migration | Project code, debugging your own logic |
| `code.claude.com/docs` + official `plugin-dev` skills | The harness itself: settings, hooks, permissions, skill/agent frontmatter, limits and context budgets | Library APIs; how this repo happens to be configured |
| `WebSearch`/`WebFetch` | Default for anything not covered above | — |
| Raw README via `raw.githubusercontent.com` | Last resort for a specific repo | — |
| Reference implementations | "How do you actually wire X together" — DI, boilerplate, layering, from real code | API truth (signatures) — that is a usage slice, not a spec |

Never `WebFetch` a rendered GitHub page (`https://github.com/...`) — the HTML is noisy and
expensive. Use raw files or an MCP tool.

## Three-step discipline

The table names **classes of source**, not a guaranteed toolset. What is actually available
varies by environment: extra MCP servers, docs/knowledge proxies, platform-specific MCP, or
additional search backends may or may not be connected.

1. **Discover** — inventory what is available right now: connected MCP servers and deferred
   tools (via `ToolSearch`), plus built-in search/fetch. A spawned subagent can both discover
   and call the session's MCP servers, so a gathering agent does its own discovery rather
   than being handed a pre-bound toolset.
2. **Use every relevant channel** — for the class of question, query **each** available
   channel that serves it, not just one. One channel is one perspective; breadth is the point.
3. **Cross-check and tier** — verify a claim across two or more channels where possible and
   rank by trust tier. Surface disagreements and version discrepancies rather than silently
   picking one.

If a whole class of channel is unavailable, state it as an explicit limitation in the output
so the reduced confidence is visible rather than silently degraded. A gathering agent records
which channels it actually used, and which classes were unavailable.

## Trust tiers

A source can be formally primary while its content is stale, about another version, or an AI
hallucination. Assign a tier before believing it.

| Tier | What | Sources |
|---|---|---|
| **T1** ground truth | artifact without interpretation | `ksrc`, existing project code, official release artifact |
| **T2** official docs | curated vendor docs, releases, changelogs | `android docs`, Context7 for official libraries, vendor changelog |
| **T3** aggregated/AI | can hallucinate | Context7 for community libraries without vendor docs |
| **T4** random web | blogs, StackOverflow, Medium, tutorials | WebSearch, arbitrary WebFetch |

**Memory is not a tier.** Auto memory and recalled facts capture what was true when written
and go stale — they are not a source of knowledge about APIs, versions, or behaviour. On a
gap or a doubt, re-check against T1/T2. Memory is a pointer to where to look, not a fact.

**Default: T1 + T2 in parallel** for any edit involving an external library. T1 alone is
acceptable with a stated reason: stable Java/Kotlin stdlib (not an evolving library); a
symbol already seen at the same pinned version with `ksrc` confirming its shape; a local
helper or data class without behaviour; trivial usage (data-class constructor, enum value,
constant). "Seems obvious" is not a reason.

**Validation before use:**
- Does the source's version match the project's? No → flag it, cross-check before using, note
  it (T1 = pinned, T2 = current; a gap means the project is behind or the docs cover another
  major).
- T3/T4 older than a year in an evolving stack (Compose/Ktor/AGP/KMP/Hilt/kotlinx.*) —
  suspect, downweight.
- T3 is never the sole source for signatures or versions; pair it with T1 or T2.
- Downgrade a tier when: the source states no version; the signature does not reproduce in
  `ksrc`; the text reads as generated (vague phrasing, fuzzy types); a tutorial or blog has
  no date.

**Conflicts:**
- **T1 vs T2** → follow T1 (what is actually available in the project), and report the
  discrepancy. On a significant gap, propose a bump.
- **T1/T2 vs T3/T4** → T1/T2 win unconditionally.
- **T2 vs T2** → a fresh vendor changelog beats an older docs page; when it is genuinely
  unclear, raise it rather than choosing silently.
