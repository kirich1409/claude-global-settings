---
name: capture-source-template
description: The actor+shim VideoFrameSource template established by ScreenSource (#28) that CameraSource (#29) mirrors
type: project
---

Onset Epic 3 capture sources follow a fixed template, first realized by `actor ScreenSource` in `Onset/Recording/Capture/ScreenSource.swift` (#28).

**Template shape** (reusable for #29 CameraSource):
- `actor` conforms to `VideoFrameSource` (contract in `Onset/Recording/Capture/CaptureSource.swift`).
- Three `AsyncStream`s (`frames`/`events`/`drops`) created in `init` as `nonisolated let`, continuations captured and held by the actor — lets subscribers attach before `start()`.
- A private `final class ...Shim: NSObject, @unchecked Sendable` bridges the framework delegate callbacks (SCStreamOutput / AVCaptureVideoDataOutputSampleBufferDelegate) into the continuations. All shim state is immutable `let`, no lock.
- Dedicated serial `DispatchQueue` (qos `.userInteractive`) for sample delivery.
- Pure `nonisolated` decision helpers extracted for unit testing (e.g. `classifyFrameStatus`, `shouldKeepFrame`) — the SCStream-specific ones do NOT transfer to camera.

**plan-at-init / anchor-at-start split:** plan + config injected at `init`; the `HostTimeAnchor` T0 arrives at `start(anchoredTo:)`. This is the #30 finalize-note seam.

**T0 / AC-7 alignment:** frames carry ABSOLUTE host-time PTS; anchor is used only for a pre-T0 drop gate, not for rebasing. Rebasing is deferred downstream to `PipelineClock.convert`. Same `HostTimeAnchor` handed to every source + FileWriter → cross-file alignment.

**Open decisions for #29 (flagged, not yet resolved):**
- CameraSource must also expose `AudioSampleSource`. `VideoFrameSource` and `AudioSampleSource` both declare `drops`/`start`/`stop` — conforming one actor to both collapses those members. Likely needs a separate audio actor.
- `.sourceInterrupted` contract semantics (PipelineTypes.swift:323) say "frames continue"; ScreenSource emits it when the stream has actually stopped. Seam divergence #34 will trip on.

**Framework isolation:** ScreenCaptureKit confined to ScreenSource + ScreenStreamConfigurationBuilder; contract layer imports only CoreMedia/CoreVideo. No backward leak — keep this when #29 lands (AVFoundation must not leak into CaptureSource/PipelineTypes).
