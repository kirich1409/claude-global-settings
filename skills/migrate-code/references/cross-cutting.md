# Cross-cutting migrations

A cross-cutting migration is one where the unit of work is an **aspect of the dependency graph or a
shared layer**, not a file. The classification signals live in `[[scope]]` § Localized vs
cross-cutting; this file owns what to do once the answer is "cross-cutting".

The flagship case is a dependency-injection or service-locator swap, and it is flagship for one
reason: it is the migration where the compiler stops being a referee while still reporting success.
Everything below is organized around that fact.

## Contents

| Section | Covers |
|---|---|
| [Unit of work: aspect, not file](#unit-of-work-aspect-not-file) | Why the per-file queue does not apply and what replaces it |
| [Dependency map is the injection graph](#dependency-map-is-the-injection-graph) | What the map contains for an aspect migration |
| [Interop bridge vs big-bang](#interop-bridge-vs-big-bang) | Both strategies and the criterion that picks between them |
| [The double-graph danger](#the-double-graph-danger) | Two containers, two instances, one silent defect class |
| [DI container migration](#di-container-migration) | Procedure and the worked example |
| [Other cross-cutting aspects](#other-cross-cutting-aspects) | Logging, error handling, analytics, flags, threading, navigation |
| [Resting states and resumability](#resting-states-and-resumability) | Where a cross-cutting migration is allowed to stop |

## Unit of work: aspect, not file

In a localized migration the queue item is a file and the completion predicate is "the target file
exists on disk" (`[[depmap-and-queue]]`). Neither survives here:

- A single file can be *fully translated* and the system still broken, because correctness depends on
  which graph configuration is active around it.
- A single file can be *untouched* and already broken, because a provider it never mentions moved to
  the other implementation.

So the queue item becomes a **slice**: a layer, a feature module, or a coherent group of bindings
that can be promoted together and observed together. Slices are ordered by the dependency map below,
and a slice is the smallest thing whose promotion leaves a bootable system.

The completion predicate must still be **derivable from repository state**, not from a note someone
kept. That is what makes the run resumable across an interruption or a lost context. Good slice
predicates:

- "no provider annotation of the outgoing framework remains under this module path";
- "the outgoing container's module list no longer registers any type owned by this slice";
- "every entry point in this slice resolves through the incoming container's entry API".

A predicate that reads "we finished the network layer on Tuesday" is not a predicate. If a slice has
no state-derivable predicate, it is not a slice yet — split it until it has one.

## Dependency map is the injection graph

For an aspect migration the dependency map from `[[depmap-and-queue]]` is not an import graph, it is
the **graph of the aspect itself**. For DI that means, per binding:

- the declared type and qualifier;
- the scope it is registered in, and the lifetime that scope really has;
- which types depend on it (its consumers) and which types it depends on;
- its entry points — the places outside the graph that pull from it (framework-instantiated classes,
  application startup, deep links, background workers);
- whether it holds state (cache, connection pool, in-memory store, hot observable) — this column
  decides which bindings can tolerate duplication and which cannot.

Topological order over consumers gives the promotion order: **leaves first**. A binding with no
in-graph consumers can move without any other binding noticing. Cycles are promoted as one slice,
exactly as cycles are batched in the localized case.

## Interop bridge vs big-bang

**Big-bang** — the whole aspect is replaced in a single change. Between the first edit and the last,
the system does not build and does not boot. One long red window, one cutover, no coexistence.

**Interop bridge** — both implementations live at once. One of them owns each type; the other reaches
it through a thin adapter instead of re-declaring it. Slices are promoted one at a time, and after
each promotion the system builds, boots, and passes its judge. Interruption leaves a working system.

Pick a direction and keep it for the whole migration. The default direction: **the outgoing
implementation keeps ownership of a type until the slice that owns it is promoted**, and the incoming
implementation resolves through the bridge in the meantime. It is the direction that keeps the
already-verified side authoritative for the longest time, and it fails loudly (a missing bridge entry
is a resolution failure at a known boundary) rather than quietly.

**Criterion.** The bridge is not automatically the safer choice. It converts one short window in which *nothing*
works into a long window in which a **compiler-invisible defect class is live**. Choose in this
order; the first failing question decides:

1. **Is there a runtime judge that can watch the coexistence window?** If no level of
   `[[verification-matrix]]` gives a judge that observes graph behavior at runtime, the bridge is
   *more* dangerous than big-bang: nothing is watching the exact hazard the bridge creates, and it is
   live for days instead of minutes. Without a runtime judge, prefer big-bang — its failure mode is a
   red build, which is at least visible. If neither strategy has a judge, that is STOP condition 1 in
   `[[scope]]`, not a strategy question.
2. **Can single ownership be established for every stateful type?** Every binding marked stateful in
   the map must be resolvable through exactly one implementation for the whole migration. If some
   stateful type cannot be bridged and must be registered on both sides, the bridge has a permanent
   double-instance defect built into it — take big-bang for that slice, or restructure the type first.
3. **Does every slice have a green, bootable resting state?** If promoting the smallest possible
   slice still leaves the application unable to start, there is no incremental path to take.
4. **Is the red window affordable?** Only now does size matter. A graph of a dozen bindings owned by
   one person for an afternoon is a big-bang; a graph spanning modules, teams, and release trains is
   a bridge.

Rules of thumb, once the questions above are answered: big-bang for small graphs, single-module
scopes, and cases where the two implementations cannot coexist at all (mutually exclusive code
generation, conflicting startup hooks). Bridge for large graphs, multi-module ownership, and any
migration expected to span more than one release cycle.

## The double-graph danger

When two containers are live at once and both register the same type, resolution and singleton
semantics change in a way **neither implementation has on its own**. The same type is now reachable
by two paths, and each path can hand out its own instance.

The symptom is never a compile error. It is:

- a cache that is warm on one screen and cold on the next;
- a login state written through one instance and unreadable through the other;
- a connection pool or database handle opened twice, with writes racing;
- an in-memory event bus where subscribers registered through one graph never see events published
  through the other;
- a configuration or feature-flag holder that reports two different values in the same session.

**The compiler is not the referee here, so the judge must be a runtime judge.** A broken injection
graph compiles perfectly: both registrations are valid code, both call sites type-check, and the
build is green. The defect exists only in the object graph that the process assembles at run time.
Which runtime level is the minimum valid one — graph verification at startup, scenario parity, or
full behavior parity — is decided by `[[verification-matrix]]`; who executes it and what it may use
as a source of truth is `[[judge]]`. Do not restate those here; do not downgrade them either. Green
build is L0 and L0 cannot see this failure class at all.

Two rules keep the danger contained:

1. **Exactly one implementation owns each type.** The other side delegates to it through the bridge.
   Never re-register a type on both sides "so it works from either place" — that sentence is the
   defect, written out in full.
2. **Identity is an assertion, not an assumption.** For every stateful binding, the judge checks
   object identity across both resolution paths — resolve through each side and assert the same
   instance. This check is cheap, mechanical, and is the single highest-value assertion in a
   cross-cutting DI migration.

## DI container migration

Procedure, once the map from above exists:

1. **Inventory the graph.** Every binding, scope, qualifier, and entry point. Mark stateful bindings.
2. **Map the concepts, not the annotations.** Scope semantics differ between frameworks even when the
   names match; the mapping table is syntax, the delta list is the payload.
3. **Choose bridge or big-bang** by the criterion above.
4. **Promote leaf slices first**, one at a time, each ending on a green build plus a runtime graph
   check.
5. **Assert identity** for every stateful binding after each promotion.
6. **Remove the bridge** as the final slice. A bridge left in place is an interop layer nobody owns.

### Worked example: DI container swap

Migrating a compile-time container to a runtime container — Dagger (or Hilt) to Koin — on an Android
codebase. The syntax mapping is mechanical:

| Outgoing | Incoming | Notes |
|---|---|---|
| `@Module` + `@Provides fun provideX(): X` | `module { factory { X() } }` | A plain `@Provides` with no scope is a new instance per request, so `factory` is the honest default, not `single` |
| `@Singleton class X @Inject constructor(...)` | `single { X(get()) }` | Constructor injection becomes explicit `get()` calls |
| `@ActivityScoped` / `@ActivityRetainedScoped` | `scope<Activity> { scoped { X(get()) } }` | The scope object now has an explicit lifetime you open and close |
| `@Named("io")` / custom `@Qualifier` annotation | `named("io")` at declaration and at `get(named("io"))` | A qualifier typo is a compile error before, a runtime resolution failure after |
| `@Binds abstract fun bind(impl: Impl): Iface` | `single<Iface> { Impl(get()) }` | The interface-to-implementation binding becomes an explicit type parameter |
| `@Component` / `@Subcomponent` | module list passed to container startup + `scope<T>` | Component nesting becomes scope nesting; there is no compile-time component graph left |

The mapping above is the easy half. The semantic deltas are what the runtime judge is checking:

- **Missing binding.** Compile-time container: build failure, with the full dependency chain in the
  message. Runtime container: an exception at first resolution — possibly three screens deep into a
  flow that only some users reach. The entire class of "missing binding" errors moves from build time
  to run time, which is why graph verification at startup becomes a first-class check rather than a
  nicety.
- **Singleton scope is not the same word.** A compile-time `@Singleton` is scoped to a component
  instance and verified statically; a runtime `single` is scoped to the container instance. Load two
  module sets that both declare the same `single`, or start a second container, and you have two
  instances of a type the code was written to assume is one.
- **Subcomponent lifetime becomes an object you must close.** A scope that is opened per screen and
  never closed leaks its whole sub-graph, and the leak is invisible to both the compiler and the unit
  tests. Every `scope<T>` opened needs a matching close on the same lifecycle boundary.
- **Qualifier resolution moves from types to strings.** Compile-time qualifiers are checked;
  `named("io")` is not. A renamed qualifier fails at resolution, in one code path.
- **Injection into framework-instantiated classes changes shape.** Field injection performed by
  generated code becomes an explicit lookup at the entry point, and every entry point must be found —
  a missed one compiles and then fails when that screen or worker first runs.

During the bridge phase, the outgoing container stays authoritative and the incoming container's
modules resolve through a single adapter binding per type (`single<X> { legacyGraph.getX() }`). No
type is declared in both. When a slice is promoted, its adapter binding is replaced by a real
declaration and the outgoing module for that slice is deleted in the same change — never in a
follow-up, because the window between those two edits is exactly the double-registration state this
file exists to prevent.

## Other cross-cutting aspects

DI is the flagship, not the only case. Each of these is an aspect with the same shape — a shared
layer, coexistence during migration, compiler blind to the failure mode — and each needs the same
treatment: slice-based queue, ownership rule, runtime judge.

- **Logging** — two backends live at once means duplicated or dropped records, and levels or
  formatters configured on one backend silently not applying to the other. Judge: capture a known
  sequence of events and compare the emitted records, not just "logging still compiles". Ownership
  rule: one sink per destination, never two writers on one file or stream.
- **Error handling** — swapping an exception model for a result type, or replacing a global handler,
  changes *where* a failure surfaces and whether it is swallowed. The dangerous outcome is not a
  crash but a silently absorbed error that used to reach the user. Judge: inject failures at known
  points and assert the observable outcome, per path, on both sides of the swap.
- **Analytics** — event names, parameter shapes, and ordering are the contract, and the consumer of
  that contract lives outside the codebase, so tests inside it cannot see a regression. Judge:
  capture the emitted event stream for a scripted session and diff it against the pre-migration
  stream, byte-comparable where the payload is serialized.
- **Feature flags** — a flag provider swap changes default values, evaluation timing, and caching. A
  flag that used to be read once at startup and is now read per call, or vice versa, changes behavior
  without changing any flag. Judge: enumerate flags, assert resolved values and evaluation counts
  against the old provider for the same remote state.
- **Dispatchers and threading** — replacing a threading model reassigns which work runs on which
  thread, and correctness of a call site depends on the model wrapping it, not on its own contents.
  Failures are order- and timing-dependent, so they are invisible to per-file review and often to
  single-run tests. Judge: assert thread confinement at the boundaries that require it (UI updates,
  database access) and run concurrency-sensitive scenarios repeatedly, not once.
- **Navigation** — a navigation framework swap changes back-stack semantics, argument passing, and
  deep-link resolution. The compiler accepts a route graph that strands a screen. Judge: traverse the
  full route graph at runtime, including back-stack behavior and every deep link, and compare against
  the pre-migration traversal.

## Resting states and resumability

`[[scope]]` STOP condition 2 allows an interruption only on a green build. In a cross-cutting
migration "green build" is necessary and not sufficient: the resting state is **the end of a promoted
slice**, where the build is green *and* the runtime graph check passes *and* the bridge is
consistent — every type owned by exactly one side.

Mid-slice is not a resting state. If work must stop mid-slice, revert the slice rather than leaving
a partially promoted graph: the reverted state is verified, the partial state is a double-registration
waiting to be discovered by a user. This is the one place where a cross-cutting migration is stricter
than a localized one, and it follows directly from the fact that the compiler will not tell anyone.

Coverage the judge needs but the project does not have is handed off as described in
`[[safety-net]]`; for a cross-cutting aspect the handoff targets are graph-level scenarios, not
individual call sites, and `scenario-judge-role` is the role that executes them.
