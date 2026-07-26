# Open-source code-search channels and the Context7 workflow

This is the single catalogue of channels in this class — the `source-researcher` agent
(`focus: oss-examples`) and the `research` skill point here rather than duplicating it. Trust
tiers and guardrails come from `stacks.md` § Reference implementations and are not overridden
here.

## Mode A — inside a known library

"How is this actually implemented / what is the exact signature in version X."

| Channel | What it gives | Tier |
|---|---|---|
| `ksrc` | Sources of **wired** JVM/Gradle dependencies from the Gradle cache — the project's exact pinned version | T1 |
| `maven-mcp` + source jar | Find the artifact on Maven Central and get sources for **any** version, including one not wired into the project (a candidate to add, or a version comparison) | T1 (official artifact) |
| Android Code Search (`cs.android.com`) | AOSP + androidx/Jetpack: platform and Jetpack sources by branch/version, plus internal usages of platform APIs inside AOSP itself | T1/T2 |
| The library's repo on GitHub/GitLab (raw files, release tags) | Sources plus the library's own tests and samples, when no source jar is published | T1/T2 |

## Mode B — across the OSS universe

"Who actually uses X and how; does a working example of Y exist."

| Channel | What it gives | Tier |
|---|---|---|
| GitHub code search (MCP `search_code` / `search_repositories`; `WebSearch` with `site:github.com` as fallback) | Usages of a symbol or pattern across GitHub, filtered by language/path/repo | by source repo (below) |
| grep.app | Fast regexp search over popular GitHub repos (JSON API `grep.app/api/search`) | by source repo |
| Sourcegraph public (`sourcegraph.com`) | Cross-host search (GitHub + GitLab and others), structural queries | by source repo |
| Android Code Search | How AOSP/Jetpack themselves use an API — reference usages for Android | T1/T2 |
| `searchcode.com` and other aggregators | Fallback discovery when direct channels are unavailable | T3/T4 |

## Caveats

- **The tier belongs to the source repository, not the search channel.** In mode B the channel
  is only transport; the code found is tiered per `stacks.md`: a vendor-endorsed stack sample
  → T1/T2, domain OSS → T3, a random repo → T4. Never the sole source for API truth —
  cross-check against T1/T2.
- **Channel availability varies by environment** (`ksrc` needs a local Gradle cache;
  `maven-mcp` and the GitHub MCP may not be connected; grep.app and Sourcegraph may be blocked
  by the session's network policy). The list is a seed for discovery, not a guarantee: apply
  the three-step discipline (discover → every available channel → cross-check) and record an
  unavailable class as an explicit limitation.
- **Do not `WebFetch` rendered GitHub pages** — use raw files or an MCP tool.

## Context7 workflow

When to reach for Context7 is decided by the routing table and the per-stack composition; the
steps once you do:

1. Start with `resolve-library-id` using the library name plus the user's question — unless an
   exact `/org/project` ID is already known.
2. Pick the best match (`/org/project`) by: exact name match, description relevance, number of
   code snippets, source reputation (High/Medium), benchmark score (higher is better). Wrong
   hit → rephrase (`next.js`, not `nextjs`), or use a versioned ID if a version is specified.
3. `query-docs` with the chosen ID and the user's full question, not a single keyword.
4. Answer from the returned docs.

One failed `resolve-library-id` → stop, do not chase synonyms. Do not use Context7 for
refactoring, writing scripts from scratch, debugging business logic, code review, or general
programming concepts.
