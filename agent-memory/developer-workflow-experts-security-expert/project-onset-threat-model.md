---
name: onset-threat-model
description: Onset security threat model — узкая поверхность атаки, реальные риски, open-source external-PR boundary
type: project
---

Onset — нативная macOS-утилита записи экрана+камеры (Swift 6, ScreenCaptureKit/AVFoundation/VideoToolbox). Threat surface намеренно узкая.

**Что УБИРАЕТ целые классы уязвимостей:**
- No network egress (AC-8 / принцип 12 product-overview): нет сетевого клиента, телеметрии, аналитики; без `com.apple.security.network.client`. Убивает SSRF, exfiltration, MITM, injection-через-сеть.
- Минимум сторонних deps (только Apple system frameworks + SwiftLint/SwiftFormat как dev-tool plugins) → тяжёлый supply-chain/SCA scan избыточен.
- Developer ID + Hardened Runtime + notarization, **без App Sandbox** (MVP; MAS post-MVP).

**Реальная поверхность риска (куда смотреть при ревью):**
1. Entitlements / TCC — config-drift (sandbox=YES вернулся, лишние app-groups, network.client entitlement протёк). Проверять на СОБРАННОМ .app (`codesign -d --entitlements -`), не на исходнике — xcodebuild инжектит часть entitlements.
2. Notarization secrets (Developer ID .p12, ASC API key) — environment-scoped GitHub secrets, не repo-wide; временный keychain в CI с `trap`-очисткой.
3. **Agent-committed-secret** — главная забота: агент генерирует конфиги подписи и может закоммитить ключ. Многослойная защита: push protection + gitleaks pre-commit + .gitignore + env-scoped secrets.

**Why:** agent-driven (код+ревью агентами, человек не пишет — принцип 15). Узость поверхности — сознательное прагматичное решение, не пробел; over-scan подрывает скорость/доверие.

**How to apply:** при ревью Onset не тратить усилия на сетевые/injection классы (их нет по сборке); фокус — entitlements allow/deny-list, no-network static-proxy (`nm`/`otool`: нет Network.framework/CFNetwork/URLSession-символов), file perms `~/Movies/Onset/`, PrivacyInfo.xcprivacy. См. [[onset-ci-security]].

**Open-source сдвиг threat model (новое, 2026-06-02):** public repo → внешние контрибьюторы открывают PR на pipeline. Новые границы поверх fork-PR boundary для L5: никакого `pull_request_target` с checkout untrusted-кода; least-privilege `permissions:` на `GITHUB_TOKEN`; auto-merge НЕ должен мержить external PR по bot/Copilot-аппруву.
