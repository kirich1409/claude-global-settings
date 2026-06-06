---
name: onset-pipeline-architecture
description: Onset Epic 3 recording pipeline — leaf-actor + AsyncStream + nonisolated-pure-core pattern, layering, and the encoder→writer PTS seam contract
type: project
---

Onset (macOS screen recorder, Swift 6 strict concurrency) builds Epic 3 as independent **leaf actors** later stitched by orchestrator `RecordingSession` (#34).

**Established leaf pattern** (verify against current code before relying):
- Each leaf is an `actor` with `nonisolated let <name>: AsyncStream<T>` output channels (drops, state, encodedSamples). Build the stream in `init` even before a consumer exists — keeps the type contract stable across waves.
- Split a **pure value-type core** (`nonisolated struct`, no CoreMedia import, fed `Double` seconds) from the actor. `CMTime → CMTimeGetSeconds` extraction happens at the actor boundary. Examples: `CFRNormalizer` beside `VideoEncoder` (Encode/); `BackpressureDegradationWindow` beside `DropMonitor` (Recording/Pipeline/).
- `stop() async` is the primary terminator: cancel+await tick task → cancel child tasks → `finish()` the stream (finish-always discipline). `deinit` is best-effort (no await).
- Live AVFoundation objects wrapped behind an injectable `nonisolated protocol` seam (`WriterInputSeam` / `CompressionSession`) for L2 testing without a live session.
- Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, value-type Equatable/Hashable need **manual `nonisolated` witnesses on the primary declaration** or they're inferred `@MainActor` and unusable from actor code.

**Layering:** Source (#28/#29, Recording/Pipeline) → Encode (VideoEncoder, Encode/) → Storage (FileWriter muxer + RecordingOutput, Storage/). Points strictly inward; leaves never reference #34 or UI. `Storage/` is the correct home for the AVAssetWriter passthrough muxer (output stage), not Encode/.

**Encoder→writer PTS seam contract (load-bearing):** FileWriter appends `EncodedSample.sampleBuffer` **raw** — NO `PipelineClock.convert()`. T0 rebase happens once via `AVAssetWriter.startSession(atSourceTime:)`. Pre-converting double-subtracts the anchor and pushes samples before session start ("PTS landmine"). As of this review the `EncodedSample`/`VideoFrame` doc-comments in PipelineTypes.swift contradicted this (said "convert before append") — flagged for fix; re-check whether corrected.

**FileWriter init constraint:** non-optional `sourceFormatHint: CMFormatDescription` required — MP4 passthrough crashes at `AVAssetWriter.add(input:)` with uncatchable NSInvalidArgumentException if nil. Forces #34 ordering: start encoder → await first EncodedSample → extract CMFormatDescription → construct FileWriter. Inherent to AVFoundation, not a design wart.

**Config injection inconsistency:** DropMonitor takes narrow scalars (decoupled from RecordingConfiguration); FileWriter takes the whole config. Scalar injection is the recommended convention for leaves. RecordingConfiguration is accreting cross-concern policy (encode+audio+durability+degraded-policy+budget) — watch cohesion, don't split at MVP scale.
