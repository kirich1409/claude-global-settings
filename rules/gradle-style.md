---
paths:
  - "**/*.gradle.kts"
  - "**/*.gradle"
  - "**/libs.versions.toml"
---

# Gradle build-скрипты

Применяется к `*.gradle.kts`, `*.gradle`, `settings.gradle*` и convention plugins в `build-logic/`
и `buildSrc/`.

## Конфигурация зависимостей

Выбирать наиболее узкую конфигурацию, при которой всё работает:

1. **`implementation`** — первый выбор. Типы зависимости не появляются в public API модуля,
   потребители не видят её в своём compile classpath, пересборки изолированы.
2. **`api`** — только когда типы зависимости появляются в public поверхности модуля.
3. **`compileOnly`** / **`runtimeOnly`** — plugin classpath, annotation processors с опциональным
   runtime, библиотеки от хоста (Android SDK, plugin runtime).

Тот же приоритет для тестов (`testImplementation`, не `testApi`) и для KMP source sets
(`commonMain.dependencies { implementation(...) }` первым).

Зависимость принадлежит `api`, если выполняется хотя бы одно:

- public-тип из зависимости появляется в сигнатуре public-объявления этого модуля;
- потребитель иначе вынужден заново объявлять ту же зависимость только ради типа, который этот
  модуль уже экспонирует;
- зависимость даёт public DSL или extension API, который потребители вызывают через этот модуль.

Иначе `implementation`. Дефолтная `public` в Kotlin делает это лёгким для пропуска — сначала
проверить видимость по `kotlin-style.md`, действительно ли символ предназначен быть public.

Стоимость ошибки асимметрична: ужать `api` → `implementation` ломает всех, кто полагался на утечку;
расширить `implementation` → `api` тривиально, и ошибка компиляции у потребителя — чёткий сигнал.
Поэтому при сомнении — `implementation`.

## Version catalogs и convention plugins

- Новые зависимости идут в `gradle/libs.versions.toml`. Координаты в build-скриптах модулей не
  хардкодить.
- Повторяющаяся build-конфигурация принадлежит convention plugins в `build-logic/`, а не
  дублируется по модулям.
- В multi-module репо перед добавлением зависимости в leaf-модуль проверить, не даёт ли её уже
  транзитивно convention plugin или upstream-модуль.
