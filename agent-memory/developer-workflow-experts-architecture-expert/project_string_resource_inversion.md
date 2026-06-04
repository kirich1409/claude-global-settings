---
name: string-resource-inversion
description: Архитектурное решение по инверсии работы со строковыми ресурсами в alfa-business — Fork B (чистая семантика), резолв только в feature-ui; StringResource-в-логике ОТВЕРГНУТ владельцем
type: project
---

Решение по инверсии работы с ресурсами (строки/тексты) в alfa-business-android.

**ЖЁСТКОЕ ОГРАНИЧЕНИЕ ВЛАДЕЛЬЦА (2026-06-02):** модель, которую логический слой (VM/presentation-логика/domain) отдаёт в UI, НЕ должна содержать НИКАКОГО понимания ресурсов — ни Android `@StringRes Int`, ни Compose `org.jetbrains.compose.resources.StringResource`, ни `Context`/`Resources`. Слова: «в UI-модели вообще не должно быть понимания интовых ID-шников ни композных ресурсов ни андроидных». Резолвинг строк — ТОЛЬКО в UI-слое.
**Why:** это ИНВЕРТИРУЕТ предыдущую рекомендацию (sealed `UiText.Resource(StringResource, args)`) — она тащила Compose-тип в логику и потому ОТВЕРГНУТА. Не предлагать её снова.

**ВЕРДИКТ: Fork B — чистая семантика.** Логика отдаёт типизированные доменные дискриминанты (валидационный enum, error-code `AlfaException`, статус, идентичность поля), несущие ДАННЫЕ, без ссылок на текст. UI владеет всеми ресурсами и маппит семантику→строку (выбор шаблона + подстановка args).

**Главный синтез:** то что отдаёт логика — это ВСЕГДА уже существующий доменный дискриминант, НИКОГДА не ключ строковой таблицы. Из этого: (1) Fork A (абстрактный ключ→ресурс) ОТВЕРГНУТ — его ключ изоморфен строковой таблице, дубль-реестр N+N+1, логика всё равно «называет какой текст»; доминируется B. (2) Fork C схлопывается в B: passthrough≈0 и plurals=0 в логике → нет кейса, заставляющего тащить resource-ref/raw-String в логику; каждый «динамический» кейс = шаблон+args, где args суть данные, шаблон выбирает UI по семантике.

**Fork B УЖЕ частично живёт в коде:** `ruble-payments-impl` — field-валидаторы возвращают `enum ValidationResult { VALID, INVALID }` (`RubleRequisitesAmountValidator`), маппинг enum→`stringManager.getString(R.string)` в VM (`setAmountError`/`setOrderError`/`handleInsertError` маппит error-code→R.string). Референс-модуль для миграции. Работа = переместить этот `when` из VM в feature-ui. `deal-registration-impl` = Fork-zero (валидаторы инжектят StringManager, возвращают `ValidationResultEntity(message: String)`) — пилот №1. Общий базис семантики уже есть: `BaseValidationResult`.

**Маппер semantic→string — per-feature `when` в feature-ui** (`when(state) -> stringResource(Res.string.x, rawArgs)`), идиоматический CMP. НИКАКОГО центрального semantic→string реестра в core — это регресс в Fork A. Core даёт только общие семантические БАЗОВЫЕ ТИПЫ (обобщённый `BaseValidationResult`), не строковую карту.

**Размещение под split feature-api/feature-logic/feature-ui:** split физически НЕ существует (2026-06-02, ни одного `*-logic`/`*-ui` модуля). Семантический тип → в feature-logic (если ui→logic) или feature-api (если сиблинги); рекомендован feature-logic. Маппер всегда в feature-ui. Инвариант: feature-logic без импортов StringRes/compose.resources/Context/R — закрепить детектом ForbiddenImport (в проекте уже включён, см. bignumkt).

**KMP:** `StringManager.nonAndroid.kt` = ПУСТОЙ actual; `getString(Int)` только в androidMain → StringManager это Android-шим, не KMP. Вытеснение = KMP-ПРЕДУСЛОВИЕ, не уборка. Семантический тип в commonMain без compose.resources. Нюанс: ограничение запрещает понимание ресурсов, НЕ форматирование — но для locale/tz-чувствительных значений тащить сырой `Instant`/`BigDecimal` и форматировать в UI (kotlinx.datetime, bignumkt, Europe/Minsk-инвариант), а не предформатированную строку.

**Вытеснение StringManager (610 usages):** инкрементально, StringManager удаляется последним. Порядок: Класс-1-чистые (deal-registration ~90% Класс1, net-new ≈0) → шаблон-100% (reservations/ruble-payments, sealed с data-полями для Класса2) → смешанные (open-account).

**Главный риск Fork B:** boilerplate на шаблонах Класса 2 (~40% обращений). Митигация: один параметризованный sealed на фичу (варианты несут данные, не тексты), Класс1 даёт net-new≈0 (перемещение, не создание), детект защищает границу. НЕ выносить общий маппер в core под предлогом дедупликации — это Fork A.
