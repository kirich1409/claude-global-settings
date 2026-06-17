---
name: onset-output-storage-security
description: Onset output-folder storage security model — POSIX perms, UserDefaults path persistence, no-sandbox threat model
type: project
---

Onset (macOS Developer-ID recorder, no App Sandbox, Hardened Runtime, no network) output-folder feature (#225, `feature/output-folder-selection`).

**Storage security model as of 2026-06-12:**
- Recording files: `0o600` via `RecordingOutput.setOwnerOnly(file:)`, called in `FileWriter.swift:266` after AVAssetWriter creates the file.
- Session leaf directory: `0o700` via `RecordingOutput.ensureDirectory(_:)` (RecordingOutput.swift:135) — `setAttributes` applies to the LEAF only, not intermediate dirs from `createDirectory(withIntermediateDirectories:true)`.
- User-selected base output dir is stored as a **plain String path** (not a security-scoped bookmark) in UserDefaults key `onset.output.baseDirectory` (`OutputFolderStore`). Justified: no sandbox → bookmarks unnecessary.
- Base dir validated by `OutputDirectoryNaming.validateBaseDirectory` (existence + writability) before each record start; `.doesNotExist`/`.notWritable` hard-stop with no silent fallback.

**Threat model context (why most path-injection findings are LOW here):** single-user personal Mac, no sandbox means a local attacker who can write the app's defaults domain already has the user's UID and full FS access at the same privilege — there is no privilege boundary to cross. Path-traversal / symlink-to-system-dir via tampered defaults grants nothing the attacker couldn't already do directly. Worst realistic case is self-inflicted misdirection of the user's own recordings.

**Privacy manifest:** `check-privacy-manifest.sh` verifies the UserDefaults required-reason category is present at CATEGORY level (reason CA92.1 in `Onset/PrivacyInfo.xcprivacy`), NOT per-key. Adding a new UserDefaults key needs no manifest change.

**PII-in-logs rule (#188):** never log full paths (contain `/Users/<name>` = PII). Diff logs only `url.lastPathComponent` (session-name segment, timestamp only). Verified clean across OutputFolderStore, RecordingOutput.uniqueSlot fault, RecordingCoordinator reveal error, RecordingSession dir create/fail.
