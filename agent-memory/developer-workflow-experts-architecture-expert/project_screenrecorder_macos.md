---
name: screenrecorder-macos
description: Greenfield native macOS 26+ recorder — captures screen 5K60 (ScreenCaptureKit) + external camera 4K60 (AVFoundation) + mic to SEPARATE files, mic embedded in video tracks, shared timecode for NLE sync
type: project
---

Greenfield project at /Users/krozov/dev/projects/ScreenRecorder. Fully native macOS app, Apple Silicon, macOS 26+, Swift only.

Scope: simultaneously record (a) screen at original res up to 5K@60 via ScreenCaptureKit, (b) external camera up to 4K@60 via AVFoundation, (c) selected microphone. Write to SEPARATE files; mic audio embedded into the video files; all sources share a common host-clock timecode so files sync later in an NLE. No real-time compositing.

Hard requirements: no dropped frames, low latency, max quality, native-only (ScreenCaptureKit, AVFoundation, Core Media, VideoToolbox, AVFAudio, AVAssetWriter).

**Why:** research/architecture-design request — user wants an opinionated design as basis for implementation plan.

**How to apply:**
- The pivotal lever is codec choice (HEVC HW-encode vs ProRes). ProRes 5K60 is multi-Gbps/stream (disk-throughput risk); HEVC 5K60+4K60 may exceed a single Apple Silicon HW encoder (encoder-saturation risk). Treat as the explicit knob driving all risk mitigations — must benchmark, fall back to HEVC.
- "No dropped frames" is not an unconditional guarantee — architecture prevents saturation (bounded ring buffer, HW encode, fast disk) and surfaces it if it happens; never silently drop.
- Real-time sample-buffer path MUST NOT be blocked: no actor hops on the hot path. Actors only for control plane.
