# Code Search Rules

Three tools cover all code navigation. Each has a distinct domain — pick the right one.

## Decision Matrix

| Task | Tool | Notes |
|------|------|-------|
| Find class / interface / struct | `ast-index class "Name"` | Covers class, interface, protocol, struct, actor, enum, object |
| Find any symbol by name | `ast-index symbol "Name"` | Optional `--type function/property/enum/typealias` |
| Universal search (symbol + file + refs) | `ast-index search "query"` | FTS5-backed, prefix match, use `--fuzzy` for approximate |
| Find all usages of a symbol | `ast-index usages "Name"` | Falls back to grep automatically if refs table is empty |
| Find all references (defs + imports + usages) | `ast-index refs "Name"` | Returns 3 sections in one call |
| Find subclasses / implementors | `ast-index implementations "Interface"` | Use for sealed hierarchies, interfaces, protocols |
| Class/type hierarchy | `ast-index hierarchy "ClassName"` | Shows full inheritance tree |
| Who calls a function | `ast-index callers "functionName"` | Grep-based, no index needed |
| Call tree (callers-of-callers) | `ast-index call-tree "fn" --depth 3` | Grep-based, configurable depth |
| Module dependencies | `ast-index deps "module-name"` | Direct deps; `dependents` for reverse |
| Reverse dependents | `ast-index dependents "module-name"` | Who depends on this module |
| Unused module deps | `ast-index unused-deps "module-name"` | Flags unused `implementation()`/`api()` |
| Symbols in a file | `ast-index outline path/to/File.kt` | Tree-sitter based |
| Imports in a file | `ast-index imports path/to/File.kt` | Index-based |
| Public API of a module | `ast-index api "module-path"` | Lists public symbols |
| Symbols changed vs branch | `ast-index changed --base main` | Git-aware diff |
| Potentially unused symbols | `ast-index unused-symbols` | Symbols with no refs; `--module` to scope |
| Extension functions | `ast-index extensions "ReceiverType"` | Grep-based |
| TODO/FIXME/HACK | `ast-index todo` | Grep-based, no index needed |
| Regex / string literal search | **Grep** | ast-index uses literal/semantic match only |
| Comment content search | **Grep** | Not indexed semantically |
| Type resolution, inferred types | **LSP hover** | Only tool returning inferred types and KDoc |
| Go to definition (type-aware) | **LSP goToDefinition** | Resolves generics, type aliases, delegation |
| Implementations (type-system aware) | **LSP goToImplementation** | Use when ast-index `implementations` is ambiguous |
| Precise call hierarchy | **LSP incomingCalls / outgoingCalls** | When `callers`/`call-tree` is insufficient |

## Priority Rules

1. **ast-index FIRST** for any "find X" task — 1-11ms, structured results
2. **LSP** when semantic type-resolution is needed (hover, exact definition, generics)
3. **Grep / Search tool** ONLY for: regex patterns, string literals, comment content, or when ast-index returns empty
4. **NEVER** run Grep "for completeness" after ast-index returned results

## Execution Modes

ast-index has two internal modes. This matters for knowing when `rebuild` is required:

| Mode | Commands | Requires `rebuild` first? |
|------|----------|--------------------------|
| **Index-based** (SQLite + FTS5) | search, symbol, class, implementations, hierarchy, usages, refs, deps, dependents, module, outline, imports, api, changed, unused-symbols, unused-deps, xml-usages, storyboard-usages, asset-usages | **Yes** |
| **Grep-based** (ripgrep internals) | todo, callers, call-tree, annotations, deprecated, suppress, provides, inject, composables, suspend, flows, extensions, deeplinks, previews, swiftui, async-funcs, publishers, main-actor, perl-* | No |

## Language Support

23 languages via tree-sitter AST parsers (auto-detected from project markers):

| Platform | Languages |
|----------|-----------|
| Android | Kotlin, Java |
| iOS | Swift, Objective-C |
| Web | TypeScript, JavaScript, Vue, Svelte |
| Systems | Rust, C/C++ |
| Backend | C#, Python, Go, Scala, PHP |
| Mobile | Dart / Flutter |
| Scripting | Ruby, Perl, Lua, Bash, Elixir |
| Data | SQL, R |
| JVM | Groovy |
| Schema | Protocol Buffers |
| Enterprise | BSL (1C:Enterprise) |

Project type auto-detected from marker files (`settings.gradle` → Android, `Package.swift` / `*.xcodeproj` → iOS, `Cargo.toml` → Rust, etc.). Override with `--project-type` flag on rebuild.

## Scoping Flags (index-based commands)

All index-based search commands support:
- `--in-file <path>` — restrict results to one file
- `--module <name>` — restrict results to one module
- `--limit N` / `-l N` — max results (default varies: 20–50)
- `--fuzzy` — fuzzy FTS5 match (search, symbol, class)
- `--format json` — machine-readable output (all commands)

## Android-Specific Commands

```bash
ast-index xml-usages "ViewClass"          # Class refs in XML layouts (index-based)
ast-index resource-usages "res_name"      # R.drawable / @string usages (index-based)
ast-index provides "Type"                 # @Provides/@Binds (grep)
ast-index inject "Type"                   # @Inject points (grep)
ast-index composables                     # @Composable functions (grep)
ast-index suspend                         # suspend functions (grep)
ast-index flows                           # Flow/StateFlow/SharedFlow (grep)
ast-index deeplinks                       # deep link patterns (grep)
ast-index previews                        # @Preview functions (grep)
ast-index annotations "Annotation"        # classes with an annotation (grep)
```

## iOS-Specific Commands

```bash
ast-index storyboard-usages "ClassName"   # class refs in .storyboard/.xib (index-based)
ast-index asset-usages "asset_name"       # xcassets image/color usages (index-based)
ast-index swiftui                         # @State/@Binding/@Published properties (grep)
ast-index async-funcs                     # Swift async functions (grep)
ast-index publishers                      # Combine publishers (grep)
ast-index main-actor                      # @MainActor annotations (grep)
```

## Programmatic / Advanced

```bash
ast-index query "SELECT * FROM symbols WHERE name LIKE 'Foo%'"  # raw SQL (read-only)
ast-index db-path                          # path to index.db (for external tools)
ast-index schema                           # all tables + row counts (JSON)
ast-index agrep "pattern" --lang kotlin    # AST structural search via sg tool
```

## Index Management

```bash
ast-index rebuild                          # Full reindex (run after clone)
ast-index rebuild --project-type ios       # Force project type
ast-index rebuild --sub-projects           # Monorepo mode (each subdir indexed)
ast-index rebuild -j 4                     # Set thread count
ast-index update                           # Incremental (runs via SessionStart hook)
ast-index watch                            # Auto-update on file changes
ast-index stats                            # Files / symbols / refs / modules / DB size
ast-index add-root <path>                  # Add extra source root
```

## Performance Reference (large Android project, ~29k files)

| Command | ast-index | grep | Speedup |
|---------|-----------|------|---------|
| `imports` | 0.3 ms | 90 ms | 260× |
| `class` | 1 ms | 90 ms | 90× |
| `usages` | 8 ms | 90 ms | 12× |
| `search` | 11 ms | 280 ms | 14× |

## LSP Operation Reference

LSP requires `filePath` + `line` + `character` (1-based) at the symbol position:

| Operation | When to use |
|-----------|-------------|
| `goToDefinition` | Precise definition with generics/delegation resolved |
| `findReferences` | Type-aware reference lookup |
| `goToImplementation` | Interface implementations (type-system aware) |
| `hover` | Inferred type + KDoc at a position |
| `documentSymbol` | All symbols in a file |
| `workspaceSymbol` | Search symbols across workspace |
| `incomingCalls` | Precise call hierarchy (callers) |
| `outgoingCalls` | Precise call hierarchy (callees) |
