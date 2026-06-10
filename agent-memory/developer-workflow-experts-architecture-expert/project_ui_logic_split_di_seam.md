---
name: ui-logic-split-di-seam
description: Архитектурный вывод по кампании UI/logic split — каскад public-расширения лечится размещением Koin-биндингов в logic, не оракулом видимости
metadata:
  type: project
---

Кампания UI/logic split (62 *-impl, 1 фича = 1 МР). Skill `.claude/skills/split-feature-ui-logic` живёт в репо и исполняется LLM-агентом буквально.

**Корневой архитектурный вывод (review 2026-06-10):** целевая граница `ui→logic→api` корректна и сдаваема — НЕ переопределять цель. Источник «неделаемости» и ревью-трения — НЕ граница, а размещение DI-поверхности. Когда entry биндит impl-ы logic'а по конкретному типу (`viewModel<X>()`, `factory<Y>()`), это форсит весь конструкторный type-tree + Ktor API + DTO-каскад в public (deposit: 150/155 флипов). requirements доказала: Koin-раскол (биндинги logic-типов остаются Koin-модулем В logic, entry только агрегирует `loadKoinModules`) режет каскад 150→50.

**Why:** §9 скилла канонизирует 150/155 как «inherent to the split» и предлагает оракул-метод лишь МИНИМИЗИРОВАТЬ флипы при данном размещении — лечит симптом, не причину. Koin-раскол спрятан в §9 как «out-of-scope follow-up», хотя кампания его уже валидировала. Противоречит non-negotiable #1 «minimal change».

**How to apply (рекомендации для редакции скилла / будущих МР):**
- Поднять Koin-раскол из follow-up в обязательный шаг Phase A: logic публикует `featureLogicModule: Module`, entry агрегирует. Тогда каскады #2 (by-concrete-type) и #3 (Ktor API→DTO) исчезают by construction.
- Переопределить «minimal» = минимум public-ПОВЕРХНОСТИ, не минимум числа флипов. Порог в done-contract: public logic = {Module + `-api`-контракты + реально-импортируемые UI типы}; data-DTO остаются internal.
- Каскад #3: если оракул требует public для data-DTO — сигнал, что API-биндинг не в том модуле; чинить размещение, не видимость.
- Parking: сузить до файлов с прямой View-ссылкой в сигнатуре; R-coupling и by-name-DI parking исключить. Связано: [[string-resource-inversion]].
- R-гейт: унифицировать на `grep "\.R\."` во всех 3 местах (non-negotiable #2, Stage 8.1, Coupling 2) — FQ-ссылки проскакивали import-grep.
