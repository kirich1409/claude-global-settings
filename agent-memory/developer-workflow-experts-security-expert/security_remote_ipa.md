---
name: security-remote-ipa-distribution
description: Security controls and accepted risks for the remote IPA distribution feature (GitHub-backed app download) in the amazing module
type: project
---

Feature `feature/remote-ipa-distribution` downloads IPA files from a private GitHub repo using a PAT, then installs on iOS devices. Banking tool, non-technical users on Windows.

**Implemented security controls (verified, do not re-flag):**
- SSRF host-allowlist in `services/GitHubClient.kt` — `isAllowedGitHubUrl` checks scheme==https + host in {api.github.com, objects.githubusercontent.com} or `.githubusercontent.com` suffix. Applied to first request AND redirect Location. OkHttp `HttpUrl` normalizes host to lowercase, keeps trailing-dot (so `host.` is rejected), and puts userinfo outside `host` — no bypass via case/trailing-dot/userinfo.
- OkHttp configured with `followRedirects(false)` in `di/AppGraph.kt` — manual 302 handling strips Authorization before following to S3. Token does NOT leak to non-github hosts.
- Path-traversal guard in `services/IpaCache.kt` `safeFile()` — canonical parent must equal cache dir. Applied to ipa/part/icon/sha files.
- Manifest id+version validated by `APP_ID_REGEX` (`^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$`) before going into file paths. displayName/description/account go ONLY to UI (Compose Text, safe) + snapshot JSON, never to paths.
- SHA-256 verified after IPA download before use; mismatch → .part deleted, failure returned. Icons are NOT hash-verified (best-effort).

**Accepted risks (in plan, do not re-flag):** plaintext PAT in settings.json; no manifest signature (sha256=integrity only, not authenticity — compromised token can serve different manifest+sha pair); no TLS pinning. PAT is read-only minimal-scope.

**Token storage note:** `services/SettingsService.kt` keeps token in MutableStateFlow<String> and plaintext settings.json. `BuildSecrets.GITHUB_TOKEN_DEFAULT` is XOR-0x5A obfuscated (cosmetic only). Token never logged.
