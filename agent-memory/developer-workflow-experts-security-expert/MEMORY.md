# Memory index

- [Onset threat model](project-onset-threat-model.md) — узкая поверхность (no network egress, минимум deps); реальный риск = entitlements/TCC + notarization secrets + agent-committed-secret; open-source добавил external-PR boundary
- [CI security posture](project-onset-ci-security.md) — двухскоростной CI; что блокирует PR vs scheduled на main; Copilot-вердикты для agent-driven; open-source меняет threat model
- [Output-folder storage security](project-onset-output-storage-security.md) — модель POSIX 0o600/0o700, plain-path UserDefaults, no-sandbox threat model, PII-in-logs (#225)
- [Remote IPA distribution security](security_remote_ipa.md) — SSRF allowlist, path-traversal, sha256, token storage controls + принятые риски фичи скачивания IPA из GitHub
- [Biometric crypto & logging](biometric_crypto_logging.md) — Insync AndroidKeyStore biometric token flow, what CrashlyticsUtil.log ships, no-secret-leak baseline
