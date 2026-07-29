---
paths:
  - "**/*.gradle.kts"
  - "**/*.gradle"
  - "**/libs.versions.toml"
---

# Gradle build-скрипты

Применяется к `*.gradle.kts`, `*.gradle`, `settings.gradle*` и convention plugins в `build-logic/`
и `buildSrc/`.

- Новые зависимости идут в `gradle/libs.versions.toml`. Координаты в build-скриптах модулей не
  хардкодить.
- Повторяющаяся build-конфигурация принадлежит convention plugins в `build-logic/`, а не
  дублируется по модулям.
- В multi-module репо перед добавлением зависимости в leaf-модуль проверить, не даёт ли её уже
  транзитивно convention plugin или upstream-модуль.
- `api` вместо `implementation` — только когда тип из зависимости появляется в public поверхности
  модуля. Стоимость ошибки асимметрична: ужать `api` → `implementation` ломает всех, кто полагался
  на утечку; расширить обратно тривиально. При сомнении — `implementation`.
