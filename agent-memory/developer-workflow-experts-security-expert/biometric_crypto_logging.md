---
name: biometric-crypto-logging
description: Insync biometric AndroidKeyStore token flow + logging pipeline — what reaches Crashlytics, no-secret-leak baseline for reviewing this area
type: project
---

Biometric token storage uses AndroidKeyStore-backed AES/CBC/PKCS7 key with `setUserAuthenticationRequired(true)` and `setInvalidatedByBiometricEnrollment(false)`.

**Why:** банковское приложение, биометрия защищает auth-токен; повышенные требования к тому, что уходит в логи/Crashlytics.

**How to apply:** при ревью любого изменения в biometric/crypto/logging этой области — проверять по этой карте, не перечитывая весь флоу заново.

## Crypto flow (do not break — these are the contract)
- Key gen / cipher: `new-core/utils/platform/.../crypto/FingerprintUtils.kt` — `generateKey()` (`@Throws` включает `IOException` через `KeyStore.load`, `KeyStoreException`, и др.), `createCipherForEncrypt()`. AES + BLOCK_MODE_CBC + ENCRYPTION_PADDING_PKCS7.
- Cipher exposed as `OnboardingViewModel.biometricCipher` (lazy) → wrapped in `CryptoObject` for `BiometricPrompt`.
- Token save: `core/.../util/TokenHelper.saveToken(token, cipher)` — генерит random 16-byte key (SecureRandom), шифрует токен на нём (AesEncryptUtil), шифрует этот key через `cipher.doFinal`, сохраняет encryptedToken+IV+encryptedKey в `settings.saveFingerprintEncryptedData`. ВНУТРИ свой немой `catch(GeneralSecurityException){ false }` — нижний слой не логирует (известный gap).
- Decrypt: `feature/authorization/.../biometric/BaseAuthorizationBiometricFragment.decryptFingerprintKey(cipher, encryptedKeyBase64)`.

## Logging pipeline — what actually reaches Crashlytics
- `core/.../util/CrashlyticsUtil.log(throwable)` = shim → `Logger.e(throwable=t){ t.message.orEmpty() }` (Kermit). Уходит: stacktrace + `message`. Реальная отправка + фильтр CancellationException в `InsyncCrashlyticsLogWriter`.
- Для KeyStore/crypto-исключений `message` генерируется AOSP ("User authentication required" и т.п.) — НЕ содержит key material / cipher / IV / токен / отпечаток / PIN. Это baseline: лог типа+message исключения безопасен.
- `BiometricPrompt.onAuthenticationError(errorCode, errString)` — errorCode (Int-константа), errString (системный человекочитаемый текст). Логировать безопасно (`w`-уровень).
- Crashlytics issue 465783e5 (~74 события) — семейство KeyStoreException на StrongBox/Secure Element устройствах при генерации ключа. Известный источник этих сбоев.

## Known gaps (defense-in-depth, не блокеры)
- `saveBiometricToken` ловит `KeyPermanentlyInvalidatedException` (наследник GeneralSecurityException) в общем catch — инвалидация ключа неотличима от рядового сбоя, осиротевшие encrypted data не чистятся. См. [[biometric-crypto-logging]] follow-up.
- `TokenHelper.saveToken` нижний `catch(GeneralSecurityException)` немой (без лога) — при заходе в область выровнять с верхним слоем.
