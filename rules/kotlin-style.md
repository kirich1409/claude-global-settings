---
paths:
  - "**/*.kt"
  - "**/*.kts"
---

# Kotlin — проектные соглашения

## Видимость привязана к структуре модулей

- Feature и implementation модули (`internal/` пакеты, `feature/.../internal/`, всё не в `api/`) →
  `internal` по умолчанию, `private` когда символ не покидает свой файл.
- Public API модули (`api/`, контракты в `:protocol/`, shared infra) → `public` только для
  предназначенного другим модулям.
- Сомневаешься между `internal` и `public` — брать `internal`: расширить позже тривиально, сузить —
  ломающее изменение.
- Ключевое слово `public` явно не писать.
- В `.kts` то же: top-level хелперы convention plugins и `build.gradle.kts` — `private`.

## Архитектура — Clean Architecture + MVI

- UseCase — одна ответственность: один public `operator fun invoke()`.
- Domain-модели без зависимостей от фреймворка (исключение: `kotlinx.coroutines`,
  `kotlinx.datetime`, аннотации `kotlinx.serialization`).
- `viewModelScope` и `lifecycleScope` принадлежат только Android presentation слою.

Проект использует другое устоявшееся соглашение — следовать проекту.
