---
name: apple-media-clock-apis
description: Verified Apple media-stack facts for multi-source A/V synchronization on macOS (CMClock, AVCaptureSession.synchronizationClock, SCStream timing) — checked against developer.apple.com 2026-05-28
type: reference
---

Verified from developer.apple.com JSON (2026-05-28) for the ScreenRecorder design [[screenrecorder-macos]]:

- `AVCaptureSession.synchronizationClock: CMClock?` is **get-only / read-only** (introduced macOS 12.3). You CANNOT inject a clock into AVCaptureSession. The session internally retimes all output sample buffers onto this clock's timebase. `masterClock` is deprecated (macOS 12.3) — `synchronizationClock` replaces it.
- The documented pattern is REVERSE sync: `sessionClock.convertTime(syncedPTS, to: originalClock)` — i.e. CMSync conversion between a capture input port's own clock (`connection.inputPorts.first?.clock`) and the session clock.
- SCStream timestamps sample buffers on the **host time clock** (`CMClockGetHostTimeClock`); SCStreamConfiguration has no clock property. So SCStream and AVCaptureSession outputs land on the SAME host timeline by default — synchronization is achieved by USING the host clock as the shared reference, not by injecting a clock.
- `SCStream.addStreamOutput(_:type:sampleHandlerQueue:)` — caller supplies the callback queue (per-source serial queue for the hot path).
- `SCStreamConfiguration.queueDepth` exists — backpressure / buffering control for the screen stream.
- SCStreamConfiguration also has `captureMicrophone` + `microphoneCaptureDeviceID` — SCStream can capture mic directly (an alternative to a separate AVCaptureAudioDataOutput).
- `SCStream.addRecordingOutput(_:)` / `SCRecordingOutput` exist — a built-in file writer; bypasses custom encoder+separate-file control, so not used for the controlled-pipeline design but worth noting as fallback.

**How to apply:** ClockService is a thin vendor of the host clock + CMSync conversion helpers, NOT something that forces a clock into the sources. Mic on audio HW clock drifts → reconcile via CMSync. Verify current names again if macOS API revs.
