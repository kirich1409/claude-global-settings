---
name: permissions-polling-lifecycle
description: How Onset's permissions screen-recording polling loop is wired (Task lifecycle, cancellation, relaunch)
type: project
---

Onset «Permissions & Onboarding» screen-recording polling design (as of 2026-06, feature/permissions-onboarding branch).

- `PermissionsService` is `@Observable @MainActor`; `startScreenPolling()` returns an unstructured `Task { [weak self] in await self?.runPollingLoop() }`. Loop: `while !Task.isCancelled { try await Task.sleep(for: 1s); guard !cancelled; refresh screen status; relaunchIfNeeded on 0→authorized edge }`.
- Lifecycle driver: `OnboardingView.task { let t = vm.startPolling(); withTaskCancellationHandler { await t.value } onCancel: { t.cancel() } }`. The `.task` modifier is the ONLY thing that stops polling — by cancelling on view disappear/replace.
- Routing is status-driven in `RootView.body` (OnsetApp.swift): no persisted onboarding-complete flag; route recomputed from `permissionsService.allGranted`. When onboarding view leaves the tree, SwiftUI cancels `.task`, which cancels the poll Task.
- Relaunch (AppRelauncher): anti-loop guard is `UserDefaults` bool `pendingScreenGrantRelaunch`; relaunch spawns new instance with `--post-screen-grant`, then `NSApp.terminate(nil)`. Screen TCC only takes effect after a fresh process launch (CGPreflight in lockstep with SCShareableContent per verify spike).

**Why:** Spec constraint — poll interval ≥1s, stop polling when onboarding closed. Screen grant on macOS is not observable in-process without relaunch.

**How to apply:** When reviewing changes here, the critical invariants are: (1) poll only runs while onboarding view is mounted; (2) cancellation is cooperative via Task.sleep throw; (3) relaunch terminates current process so poll loop teardown is moot on the grant path. Camera/mic grants do NOT stop the loop — it polls screen only and keeps ticking until view teardown; that is by design (cheap CGPreflight, ≥1s).
