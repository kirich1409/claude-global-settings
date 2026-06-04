# Code Search Rules

Three tools cover all code navigation. Pick the right one — run `ast-index --help` or `ast-index <command> --help` for full syntax.

## Decision Matrix

| Task | Tool |
|------|------|
| Find class / interface / struct | `ast-index class "Name"` |
| Find any symbol by name | `ast-index symbol "Name"` |
| Universal search (symbol + file + refs) | `ast-index search "query"` |
| Find all usages of a symbol | `ast-index usages "Name"` |
| Find all references (defs + imports + usages) | `ast-index refs "Name"` |
| Find subclasses / implementors | `ast-index implementations "Interface"` |
| Class/type hierarchy | `ast-index hierarchy "ClassName"` |
| Who calls a function | `ast-index callers "functionName"` |
| Call tree | `ast-index call-tree "fn" --depth 3` |
| Module dependencies | `ast-index deps "module-name"` |
| Reverse dependents | `ast-index dependents "module-name"` |
| Symbols in a file | `ast-index outline path/to/File.kt` |
| Public API of a module | `ast-index api "module-path"` |
| Potentially unused symbols | `ast-index unused-symbols` |
| TODO/FIXME/HACK | `ast-index todo` |
| Regex / string literal search | **Grep** |
| Comment content search | **Grep** |
| Type resolution, inferred types | **LSP hover** |
| Go to definition (type-aware) | **LSP goToDefinition** |
| Precise call hierarchy | **LSP incomingCalls / outgoingCalls** |

## Priority Rules

1. **ast-index FIRST** for any "find X" task — structured results, 1-11ms
2. **LSP** when semantic type-resolution is needed (hover, exact definition, generics)
3. **Grep** ONLY for regex patterns, string literals, comments, or when ast-index returns empty
4. **NEVER** run Grep "for completeness" after ast-index returned results

## Hard Rules — No Exceptions

- **NEVER use Grep to search for a class, function, interface, variable, or any code symbol by name.** This is always ast-index territory.
- **NEVER use Glob to find a source file by class/module name.** Use `ast-index search` or `ast-index class`.
- If ast-index reports "Index not found" — stop and bootstrap it: run `ast-index rebuild` via Bash (works from any agent, including Explore, which has no Skill tool), or the matching `ast-index:initialize-*` skill if the Skill tool is available. Then retry. Do NOT fall back to Grep, and do NOT skip the search.
- Grep is permitted ONLY for: string literals in code, regex patterns, comment text, config values, log messages.

## Large-File Reads

- Before `Read` on any file longer than ~500 lines, run `ast-index outline <file>` first, then `Read` only the needed slice via `offset` / `limit`. The outline gives the symbol map to target the exact range — do not bulk-read large files.

## Session Start Check

If the session reminder contains `⚠ AST INDEX NOT AVAILABLE` — the index is not initialized for this project. Before any code search:
1. Identify the project type (Android/iOS/Web/Rust/etc.)
2. Bootstrap the index: `ast-index rebuild` via Bash, or the matching `ast-index:initialize-*` skill if the Skill tool is available
3. Only then proceed with code navigation

## Index Freshness — Automated

The index is kept current by hooks; no manual `update` is needed in normal work:

- **SessionStart** runs `ast-index update` (incremental reconcile) or `rebuild` if the index is missing, then launches a detached, single-instance `ast-index watch` daemon for the project. The watcher catches **all** file changes — editor, subagent, terminal, `git pull`/`checkout`/`rebase`, build output — and updates incrementally. `watch` self-enforces one instance per project, so re-launch is a safe no-op. The `~/.claude` config repo is deliberately excluded from the watcher (its index is still built for searching hooks/scripts).
- **PostToolUse:EnterWorktree** (`hooks/ast-index-bootstrap-worktree.sh`) bootstraps a freshly-entered worktree's index and launches its own watcher — ast-index is per-worktree and does not carry over.

The watcher persists after the session ends (it is not auto-reaped), so several lightweight watchers may accumulate across a day until reboot; a duplicate launch exits cleanly.

If a subagent still hits "Index not found" in a code worktree, it must `ast-index rebuild` (it has Bash) — never skip to Grep.
