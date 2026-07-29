# Gap inventory

<!-- copy verbatim -->

One row per site the RULEBOOK cannot translate mechanically. Appended to as sites surface during
Phase 3 fan-out and review; a row is removed only once its marker is resolved and the marked code
no longer carries it. See `rulebook.md` for what each marker means and why a marker without a row
here is a leak.

## Columns

| Column | Meaning |
|---|---|
| `site` | File path plus line, symbol, or function that identifies the location |
| `reason` | Why the RULEBOOK does not cover this site mechanically |
| `marker` | One of `TODO(port)`, `BUG(port)`, `PERF(port)` |
| `owner` | Role responsible for resolving the row |
| `status` | `open` or `resolved` |

## Skeleton (tab-separated)

```
site	reason	marker	owner	status
```

### Example (stack-specific)

```
app/src/parser/Parser.kt:42	custom delegate has no direct kotlinx.serialization equivalent	TODO(port)	implementer-role	open
app/src/parser/Parser.kt:88	migrated read path returns a different error type on malformed input	BUG(port)	fixer-role	open
```
