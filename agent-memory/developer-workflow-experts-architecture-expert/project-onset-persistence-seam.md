---
name: onset-persistence-seam
description: Onset device-selection persistence — protocol+UserDefaults store seam shape, where reconciliation logic should live, #92 reuse path
type: project
---

Device-selection persistence (#109) introduced the project's FIRST and only UserDefaults key family (`onset.device.*` in `Onset/Configuration/DeviceSelectionKeys.swift`). Pattern: `DeviceSelectionPersisting` protocol + `UserDefaultsDeviceSelectionStore(defaults: = .standard)` struct in `Onset/Storage/`, wired into `MainViewModel` via a `makeStore: () -> any DeviceSelectionPersisting` closure seam (matches the VM's other closure seams: `discoverCameras`, `makeCameraSource`).

**Why this shape:** store is a stateless struct over shared backing (UserDefaults.standard in prod, captured `inMemory` in tests) — a struct not an actor because UserDefaults is thread-safe + synchronous; an actor would force needless async + MainActor hop on the `didSet` persist path. Corruption-tolerance (bad/missing blob → nil, never throws) lives in the store, honoring stability-priority-#1 at the I/O boundary. Tests inject via `withScopedDefaults`/`InMemoryUserDefaults` (`OnsetTests/ScopedDefaults.swift`, issue #110 — never call `UserDefaults(suiteName:)` directly in tests).

**Two known refinement gaps (flagged, not blockers):**
1. Reconciliation branching (saved record × available list → restore / disconnected-notice / fall-through) is inline in `MainViewModel+Devices.swift` instead of extracted into a pure `nonisolated` resolver — violates the project's pure-logic-extraction convention (cf. `EffectivePermissions`, `CapabilityResolver`, `MenuBarLabelMapper`).
2. Protocol is 6 methods (3 ops × 2 roles). #92 (per-file microphone) adds device *roles*; a role-parameterized API (`save(_:for: DeviceRole)`) would absorb new roles without per-role protocol growth.

**How to apply:** When #92 or any new persisted-device-role work lands, push for the resolver extraction + role-parameterized protocol — #92 is the named reuse case that makes both non-speculative. Reuse `DeviceSelectionRecord(uniqueID, localizedName)` + the `onset.device.*` namespace as-is; they extend without churn.
