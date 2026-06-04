---
name: onset-layering
description: Onset module dependency contract and how Permissions slots into it; key boundary types
type: project
---

Onset (macOS SwiftUI recorder) layering contract — source of truth is `docs/specs/2026-06-02-onset-product-overview.md` principle #10.

Allowed edges: `UI → Recording → {Capture, Encode, Capability} → Configuration`. `Configuration` depends on nobody. `Permissions` is a SEPARATE layer that `Recording` and `UI`-onboarding depend on, but it must NOT depend on UI. No back-edges. `/acceptance` validates against this.

**Why:** agent-driven dev (#15) — spec is the only autonomous contract; the dependency rule is machine-checkable and the gate against which reviews run.

**How to apply:**
- `Onset/Permissions/*` must stay free of SwiftUI and any UI-type reference. `AppKit` (NSWorkspace/NSApp for deep-link + relaunch) IS sanctioned by the contract — do not flag it as a layer violation.
- The clean cross-layer boundary for the upcoming Recording feature is `EffectivePermissions` — a `nonisolated` Equatable value type. Recording actors consume a snapshot of it without touching the `@MainActor PermissionsProviding` protocol or hopping actors. Treat this value-type boundary as the intended seam, not a problem.
- DI: composition root in `OnsetApp` (`OnsetApp.swift`), constructor injection only, no DI lib (#stack table). `@Observable @MainActor` services; MVVM with `@Observable` view-models.
- Recurring MVVM smell to watch in UI layer: a VM exposing its raw injected dependency (`var permissionsService: any PermissionsProviding`) lets views reach through and bypass VM guards — prefer per-action wrapper methods. See [[onset-audio-scope]] for product scope context.
